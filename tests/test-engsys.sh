#!/bin/sh

set -eu

system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)
cleanup() {
  cleanup_status=$?
  rm -rf "$test_dir"
  trap - 0 1 2 15
  exit "$cleanup_status"
}
trap cleanup 0 1 2 15

git -C "$test_dir" init -q
mkdir -p "$test_dir/.claude/rules"
printf '%s\n' 'project-owned route' >"$test_dir/.claude/rules/engineering-system.md"

"$system_root/bin/engsys" init \
  --project "$test_dir" \
  --name fixture-service \
  --verify 'make check' \
  --source 'runtime=src/' \
  --source 'schema=migrations/' \
  --policy docs/documentation-policy.md \
  --architecture docs/architecture/README.md \
  --generated docs/architecture/data-model.md 'make docs-schema --check' \
  --lifecycle design docs/design implemented \
  --lifecycle adr docs/adr accepted

[ -f "$test_dir/.engsys/project.yaml" ]
[ -f "$test_dir/.engsys/lock.yaml" ]
[ -f "$test_dir/.engsys/generated-paths.txt" ]
grep -Fq "name: 'fixture-service'" "$test_dir/.engsys/project.yaml"
grep -Fq "verify: 'make check'" "$test_dir/.engsys/project.yaml"
grep -Fq "output: 'docs/architecture/data-model.md'" "$test_dir/.engsys/project.yaml"
grep -Fxq 'docs/architecture/data-model.md' "$test_dir/.engsys/generated-paths.txt"
grep -Fxq 'project-owned route' "$test_dir/.claude/rules/engineering-system.md"
"$system_root/bin/engsys" check --project "$test_dir"

if "$system_root/bin/engsys" init --project "$test_dir" --verify 'make check' >/dev/null 2>&1; then
  printf '%s\n' 'init overwrote an existing contract' >&2
  exit 1
fi

printf '%s\n' 'docs/another-generated.md' >>"$test_dir/.engsys/generated-paths.txt"
if "$system_root/bin/engsys" check --project "$test_dir" >/dev/null 2>&1; then
  printf '%s\n' 'check accepted stale generated paths' >&2
  exit 1
fi
"$system_root/bin/engsys" sync --project "$test_dir"
"$system_root/bin/engsys" check --project "$test_dir"
