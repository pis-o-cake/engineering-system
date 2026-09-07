#!/bin/sh

# 계약 형식의 정본은 schemas/*.json이다. bootstrap이 쓰는 형식, sh check가 읽는 형식, schema가
# 세 갈래로 갈라지지 않았는지 확인한다.
set -eu

system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
command -v python3 >/dev/null 2>&1 \
  || { printf '%s\n' 'python3 is required for Engineering System development tests' >&2; exit 1; }

test_dir=$(mktemp -d)
cleanup() {
  cleanup_status=$?
  rm -rf "$test_dir"
  trap - 0 1 2 15
  exit "$cleanup_status"
}
trap cleanup 0 1 2 15

python3 "$system_root/tools/validate-contract.py" \
  project "$system_root/examples/project.yaml" \
  lock "$system_root/examples/lock.yaml"

git -C "$test_dir" init -q
"$system_root/bin/engsys" init \
  --project "$test_dir" \
  --name schema-fixture \
  --verify 'printf project-verification' \
  --source 'runtime=src/' \
  --policy docs/documentation-policy.md \
  --architecture docs/architecture/README.md \
  --generated docs/architecture/data-model.md 'printf generated-verification' \
  --lifecycle design docs/design implemented \
  --lifecycle adr docs/adr accepted >/dev/null

# bootstrap 산출물이 schema를 만족해야 writer와 schema가 같은 형식을 말하는 것이다.
python3 "$system_root/tools/validate-contract.py" --project-dir "$test_dir"

# 최소 옵션으로 만든 계약도 같은 형식이어야 한다.
minimal_dir="$test_dir/minimal"
mkdir -p "$minimal_dir"
git -C "$minimal_dir" init -q
"$system_root/bin/engsys" init --project "$minimal_dir" --verify 'printf ok' >/dev/null
python3 "$system_root/tools/validate-contract.py" --project-dir "$minimal_dir"

# schema 위반은 schema 검증과 프로젝트쪽 sh check 양쪽에서 걸려야 한다.
printf '%s\n' "bogus: 'value'" >>"$test_dir/.engsys/project.yaml"
if python3 "$system_root/tools/validate-contract.py" --project-dir "$test_dir" >/dev/null 2>&1; then
  printf '%s\n' 'schema validation accepted an unknown top-level key' >&2
  exit 1
fi
if "$system_root/bin/engsys" check --project "$test_dir" >/dev/null 2>&1; then
  printf '%s\n' 'engsys check accepted an unknown top-level key' >&2
  exit 1
fi
