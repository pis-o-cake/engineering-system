#!/usr/bin/env python3
"""시스템 카탈로그·root plugin manifest·skill이 서로 어긋나지 않았는지 검사한다.

package 선언이 정본이고 system.yaml, root `.claude-plugin/plugin.json`, hook catalog는 그
선언을 반영한 사본이다. 사본은 사람이 고치다 갈라지므로 여기서 기계적으로 대조한다.
adapters/claude-code/contract.yaml이 선언한 context budget도 같이 강제한다.

Example:
    python3 tools/check-consistency.py
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))

import engsys_yaml  # noqa: E402

SYSTEM_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROUTE_TEMPLATE = os.path.join(
    SYSTEM_ROOT, "templates", "project", ".claude", "rules", "engineering-system.md"
)
HOOK_COMMAND_TEMPLATE = 'sh "${CLAUDE_PLUGIN_ROOT}/packages/%s/%s"'


def main(argv):
    if argv:
        print("usage: check-consistency.py", file=sys.stderr)
        return 2

    catalog = engsys_yaml.load(os.path.join(SYSTEM_ROOT, "system.yaml"))
    budget = engsys_yaml.load(
        os.path.join(SYSTEM_ROOT, "adapters", "claude-code", "contract.yaml")
    )["context-budget"]

    errors = []
    packages = _load_packages(catalog, errors)
    errors.extend(_check_profiles(catalog))
    errors.extend(_check_plugin_manifest(catalog, packages))
    errors.extend(_check_hook_catalog(packages))
    errors.extend(_check_skills(packages, budget))
    errors.extend(_check_route_template(budget))

    if errors:
        print("FAIL system catalog is inconsistent", file=sys.stderr)
        for error in errors:
            print("  %s" % error, file=sys.stderr)
        return 1
    print("ok system catalog, plugin manifest, and skills agree")
    return 0


def _load_packages(catalog, errors):
    packages = {}
    for name, entry in (catalog.get("packages") or {}).items():
        manifest_path = os.path.join(SYSTEM_ROOT, entry["path"], "package.yaml")
        if not os.path.isfile(manifest_path):
            errors.append("system.yaml references a missing package manifest: %s" % manifest_path)
            continue
        package = engsys_yaml.load(manifest_path)["package"]
        if package.get("name") != name:
            errors.append(
                "package manifest name '%s' does not match catalog key '%s'"
                % (package.get("name"), name)
            )
        if package.get("version") != entry.get("version"):
            errors.append(
                "%s: system.yaml version '%s' does not match package.yaml version '%s'"
                % (name, entry.get("version"), package.get("version"))
            )
        if package.get("status") != entry.get("status"):
            errors.append(
                "%s: system.yaml status '%s' does not match package.yaml status '%s'"
                % (name, entry.get("status"), package.get("status"))
            )
        packages[name] = {"path": entry["path"], "package": package}
    return packages


def _check_profiles(catalog):
    errors = []
    known = set(catalog.get("packages") or {})
    for name, entry in (catalog.get("profiles") or {}).items():
        profile_path = os.path.join(SYSTEM_ROOT, entry["path"])
        if not os.path.isfile(profile_path):
            errors.append("profile file is missing: %s" % entry["path"])
            continue
        declared = engsys_yaml.load(profile_path).get("packages") or []
        listed = entry.get("packages") or []
        if declared != listed:
            errors.append(
                "profile '%s': system.yaml lists %s but %s declares %s"
                % (name, listed, entry["path"], declared)
            )
        for package in declared:
            if package not in known:
                errors.append("profile '%s' references unknown package '%s'" % (name, package))
    return errors


def _check_plugin_manifest(catalog, packages):
    manifest_path = os.path.join(SYSTEM_ROOT, ".claude-plugin", "plugin.json")
    with open(manifest_path, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)

    errors = []
    system_version = (catalog.get("system") or {}).get("version")
    if manifest.get("version") != system_version:
        errors.append(
            "root plugin.json version %r does not match system.yaml version %r"
            % (manifest.get("version"), system_version)
        )

    expected = set()
    for name, entry in packages.items():
        for skill in _declared_skills(entry):
            expected.add("./%s/%s" % (entry["path"], skill))
    declared = set(manifest.get("skills") or [])

    for missing in sorted(expected - declared):
        errors.append("root plugin.json is missing a declared skill: %s" % missing)
    for extra in sorted(declared - expected):
        errors.append("root plugin.json declares an unknown skill: %s" % extra)

    hooks_path = manifest.get("hooks")
    if not isinstance(hooks_path, str):
        errors.append("root plugin.json must point at a hook catalog file")
    elif not os.path.isfile(os.path.join(SYSTEM_ROOT, hooks_path)):
        errors.append("root plugin.json hook catalog is missing: %s" % hooks_path)
    return errors


def _check_hook_catalog(packages):
    catalog_path = os.path.join(SYSTEM_ROOT, "adapters", "claude-code", "hooks", "catalog.json")
    with open(catalog_path, "r", encoding="utf-8") as handle:
        catalog = json.load(handle)

    expected = set()
    errors = []
    for name, entry in packages.items():
        for hook in _declared_hooks(entry):
            handler = os.path.join(SYSTEM_ROOT, entry["path"], hook["command"])
            if not os.path.isfile(handler):
                errors.append("%s declares a missing hook handler: %s" % (name, hook["command"]))
            expected.add(
                (
                    hook["event"],
                    hook["matcher"],
                    HOOK_COMMAND_TEMPLATE % (name, hook["command"]),
                    hook["timeout"],
                )
            )

    declared = set()
    for event, matchers in (catalog.get("hooks") or {}).items():
        for matcher_entry in matchers:
            for hook in matcher_entry.get("hooks") or []:
                declared.add(
                    (event, matcher_entry.get("matcher"), hook.get("command"), hook.get("timeout"))
                )

    for missing in sorted(expected - declared):
        errors.append("hook catalog is missing a declared hook: %s" % (missing,))
    for extra in sorted(declared - expected):
        errors.append("hook catalog declares an unknown hook: %s" % (extra,))
    return errors


def _check_skills(packages, budget):
    errors = []
    description_limit = budget["skill-description-max-characters"]
    body_limit = budget["skill-instructions-max-lines"]
    for name, entry in packages.items():
        for skill in _declared_skills(entry):
            directory = os.path.join(SYSTEM_ROOT, entry["path"], skill)
            document = os.path.join(directory, "SKILL.md")
            if not os.path.isfile(document):
                errors.append("%s declares a missing skill: %s" % (name, skill))
                continue
            frontmatter, body = _split_frontmatter(document)
            if frontmatter is None:
                errors.append("%s/%s: SKILL.md has no frontmatter" % (name, skill))
                continue
            expected_name = os.path.basename(skill)
            if frontmatter.get("name") != expected_name:
                errors.append(
                    "%s/%s: frontmatter name '%s' does not match its directory"
                    % (name, skill, frontmatter.get("name"))
                )
            description = frontmatter.get("description") or ""
            if not description:
                errors.append("%s/%s: SKILL.md has no description" % (name, skill))
            elif len(description) > description_limit:
                errors.append(
                    "%s/%s: description is %d characters, over the %d limit"
                    % (name, skill, len(description), description_limit)
                )
            if len(body) > body_limit:
                errors.append(
                    "%s/%s: instructions are %d lines, over the %d limit"
                    % (name, skill, len(body), body_limit)
                )
    return errors


def _check_route_template(budget):
    limit = budget["project-route-max-lines"]
    with open(ROUTE_TEMPLATE, "r", encoding="utf-8") as handle:
        lines = handle.read().splitlines()
    if len(lines) > limit:
        return [
            "templates project route is %d lines, over the %d limit" % (len(lines), limit)
        ]
    return []


def _declared_skills(entry):
    adapter = entry["package"].get("claude-code") or {}
    return adapter.get("skills") or []


def _declared_hooks(entry):
    adapter = entry["package"].get("claude-code") or {}
    return adapter.get("hooks") or []


def _split_frontmatter(path):
    with open(path, "r", encoding="utf-8") as handle:
        lines = handle.read().splitlines()
    if not lines or lines[0].strip() != "---":
        return None, lines
    for position in range(1, len(lines)):
        if lines[position].strip() == "---":
            block = "\n".join(lines[1:position])
            return engsys_yaml.load_text(block), lines[position + 1 :]
    return None, lines


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
