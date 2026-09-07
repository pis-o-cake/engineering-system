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
  --verify 'printf project-verification' \
  --source 'runtime=src/' \
  --source 'schema=migrations/' \
  --policy docs/documentation-policy.md \
  --architecture docs/architecture/README.md \
  --generated docs/architecture/data-model.md 'printf generated-verification' \
  --lifecycle design docs/design implemented \
  --lifecycle adr docs/adr accepted

[ -f "$test_dir/.engsys/project.yaml" ]
[ -f "$test_dir/.engsys/lock.yaml" ]
[ -f "$test_dir/.engsys/generated-paths.txt" ]
grep -Fq "name: 'fixture-service'" "$test_dir/.engsys/project.yaml"
grep -Fq "verify: 'printf project-verification'" "$test_dir/.engsys/project.yaml"
grep -Fq "output: 'docs/architecture/data-model.md'" "$test_dir/.engsys/project.yaml"
grep -Fxq 'docs/architecture/data-model.md' "$test_dir/.engsys/generated-paths.txt"
grep -Fxq 'project-owned route' "$test_dir/.claude/rules/engineering-system.md"
grep -Fq '  pipeline:' "$test_dir/.engsys/lock.yaml"
"$system_root/bin/engsys" check --project "$test_dir"
verification=$("$system_root/bin/engsys" verify --project "$test_dir")
printf '%s' "$verification" | grep -Fq 'project-verification'
printf '%s' "$verification" | grep -Fq 'generated-verification'

if "$system_root/bin/engsys" init --project "$test_dir" --verify 'printf ok' >/dev/null 2>&1; then
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

# A newer catalog may add a profile package. The existing lock remains the authority until an
# explicit upgrade; otherwise central updates would silently change old projects.
sed '/^  pipeline:$/,/^    revision:/d' "$test_dir/.engsys/lock.yaml" >"$test_dir/.engsys/lock.yaml.next"
mv "$test_dir/.engsys/lock.yaml.next" "$test_dir/.engsys/lock.yaml"
"$system_root/bin/engsys" check --project "$test_dir"
upgrade_plan=$("$system_root/bin/engsys" upgrade --project "$test_dir")
printf '%s' "$upgrade_plan" | grep -Fq 'pipeline: added'
"$system_root/bin/engsys" upgrade --project "$test_dir" --apply
grep -Fq '  pipeline:' "$test_dir/.engsys/lock.yaml"
"$system_root/bin/engsys" check --project "$test_dir"
