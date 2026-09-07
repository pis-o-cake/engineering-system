#!/usr/bin/env python3
"""Check this repository's declared historical metadata and local link targets.

The native check reads lifecycle paths from .engsys/project.yaml and status vocabulary
from its documentation policy. It does not compare frozen prose with current code,
rewrite records, fetch external links, or validate heading fragments.
"""

from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import engsys_yaml  # noqa: E402

SYSTEM_ROOT = Path(__file__).resolve().parent.parent
INLINE_LINK = re.compile(r"\[[^\]\n]*\]\(\s*(<[^>\n]+>|[^\s)]+)(?:\s+['\"][^\n]*?['\"])?\s*\)")
REFERENCE_LINK = re.compile(r"^ {0,3}\[[^\]\n]+\]:\s*(<[^>\n]+>|\S+)", re.MULTILINE)


def inside(root, value):
    if not isinstance(value, str) or not value or Path(value).is_absolute():
        raise ValueError("expected a nonempty repository-relative path: %r" % value)
    path = (root / value).resolve()
    if not path.is_relative_to(root):
        raise ValueError("path leaves the repository: %s" % value)
    return path


def frontmatter(text):
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        raise ValueError("missing frontmatter")
    for index in range(1, len(lines)):
        if lines[index] == "---":
            metadata = engsys_yaml.load_text("\n".join(lines[1:index]))
            if not isinstance(metadata, dict):
                raise ValueError("frontmatter must be a mapping")
            return metadata, "\n".join(lines[index + 1:])
    raise ValueError("unterminated frontmatter")


def prose(text):
    """Exclude code examples before looking for Markdown link destinations."""
    lines = []
    fence = None
    for line in text.splitlines():
        marker = re.match(r"^ {0,3}(`{3,}|~{3,})", line)
        if fence:
            if marker and marker[1][0] == fence[0] and len(marker[1]) >= len(fence):
                fence = None
            continue
        if marker:
            fence = marker[1]
            continue
        if line.startswith("    ") or line.startswith("\t"):
            continue
        lines.append(line)
    return re.sub(r"(`+).*?\1", "", "\n".join(lines), flags=re.DOTALL)


def local_link_errors(root, path, body):
    text = prose(body)
    errors = []
    destinations = [match[1] for pattern in (INLINE_LINK, REFERENCE_LINK)
                    for match in pattern.finditer(text)]
    for destination in destinations:
        destination = destination.removeprefix("<").removesuffix(">")
        url = urlsplit(destination)
        if url.scheme or url.netloc or not url.path:
            continue
        relative = unquote(url.path)
        target = root / relative.lstrip("/") if relative.startswith("/") else path.parent / relative
        target = target.resolve()
        if not target.is_relative_to(root) or not target.exists():
            errors.append("broken local link: %s" % destination)
    return errors


def check(root):
    root = Path(root).resolve()
    contract = engsys_yaml.load(root / ".engsys/project.yaml")
    documentation = contract.get("documentation") or {}
    lifecycles = documentation.get("lifecycle") or {}
    if not lifecycles:
        return []
    policy_path = inside(root, documentation.get("policy"))
    policy = engsys_yaml.load(policy_path).get("historical-records") or {}
    required = policy.get("required-frontmatter")
    vocabulary = policy.get("statuses") or {}
    if not isinstance(required, list) or not required:
        raise ValueError("documentation policy must declare historical-records.required-frontmatter")

    errors = []
    for name, lifecycle in lifecycles.items():
        statuses = vocabulary.get(name)
        if not isinstance(statuses, list) or not statuses:
            errors.append("%s: no lifecycle status vocabulary in documentation policy" % name)
            continue
        unknown_frozen = set(lifecycle.get("frozen-status") or []) - set(statuses)
        if unknown_frozen:
            errors.append("%s: unknown frozen-status %s" % (name, sorted(unknown_frozen)))
        directory = inside(root, lifecycle.get("path"))
        if not directory.exists():
            errors.append("%s: lifecycle path does not exist: %s" % (name, lifecycle.get("path")))
            continue
        paths = sorted(directory.rglob("*.md")) if directory.is_dir() else [directory]
        for path in paths:
            relative = path.relative_to(root)
            try:
                metadata, body = frontmatter(path.read_text(encoding="utf-8"))
                for key in required:
                    if not isinstance(metadata.get(key), str) or not metadata[key].strip():
                        errors.append("%s: missing or empty frontmatter %s" % (relative, key))
                if metadata.get("status") not in statuses:
                    errors.append("%s: unknown status %r" % (relative, metadata.get("status")))
                errors.extend("%s: %s" % (relative, error)
                              for error in local_link_errors(root, path, body))
            except (OSError, ValueError, engsys_yaml.YamlSubsetError) as error:
                errors.append("%s: %s" % (relative, error))
    return errors


def main(argv):
    if argv:
        print("usage: check-documentation.py", file=sys.stderr)
        return 2
    try:
        errors = check(SYSTEM_ROOT)
    except (OSError, ValueError, engsys_yaml.YamlSubsetError) as error:
        errors = [str(error)]
    if errors:
        for error in errors:
            print("FAIL documentation: %s" % error, file=sys.stderr)
        return 1
    print("ok historical frontmatter, lifecycle statuses, and local link targets")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
