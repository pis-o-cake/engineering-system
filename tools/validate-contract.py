#!/usr/bin/env python3
"""프로젝트 계약과 lock이 schemas/의 JSON Schema를 만족하는지 검사한다.

`bin/engsys check`는 프로젝트에서 dependency 없이 도는 구조 검사이고, 이 도구는 계약 형식의
정본인 schema와 writer/parser가 갈라지지 않았는지 시스템 레포 test에서 확인하는 용도다.

Example:
    python3 tools/validate-contract.py project examples/project.yaml
    python3 tools/validate-contract.py --project-dir /path/to/repo
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))

import engsys_yaml  # noqa: E402
import jsonschema_min  # noqa: E402

SYSTEM_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCHEMAS = {
    "project": os.path.join(SYSTEM_ROOT, "schemas", "project.schema.json"),
    "lock": os.path.join(SYSTEM_ROOT, "schemas", "lock.schema.json"),
}
USAGE = (
    "usage: validate-contract.py <project|lock> <file> [<project|lock> <file> ...]\n"
    "       validate-contract.py --project-dir <directory>"
)


def main(argv):
    targets = _parse_arguments(argv)
    if targets is None:
        print(USAGE, file=sys.stderr)
        return 2

    failed = False
    for kind, path in targets:
        errors = _validate(kind, path)
        if errors:
            failed = True
            print("FAIL %s (%s contract)" % (path, kind), file=sys.stderr)
            for error in errors:
                print("  %s" % error, file=sys.stderr)
        else:
            print("ok %s (%s contract)" % (path, kind))
    return 1 if failed else 0


def _parse_arguments(argv):
    if len(argv) == 2 and argv[0] == "--project-dir":
        directory = argv[1]
        return [
            ("project", os.path.join(directory, ".engsys", "project.yaml")),
            ("lock", os.path.join(directory, ".engsys", "lock.yaml")),
        ]
    if not argv or len(argv) % 2 != 0:
        return None
    targets = []
    for position in range(0, len(argv), 2):
        kind = argv[position]
        if kind not in SCHEMAS:
            return None
        targets.append((kind, argv[position + 1]))
    return targets


def _validate(kind, path):
    if not os.path.isfile(path):
        return ["file does not exist"]
    with open(SCHEMAS[kind], "r", encoding="utf-8") as handle:
        schema = json.load(handle)
    try:
        document = engsys_yaml.load(path)
    except engsys_yaml.YamlSubsetError as error:
        return ["unreadable contract: %s" % error]
    return jsonschema_min.validate(document, schema)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
