#!/bin/sh

# package 선언이 정본이고 system.yaml·root plugin manifest·hook catalog는 사본이다. 사본이
# 갈라지면 실패해야 한다.
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

python3 "$system_root/tools/check-consistency.py"
python3 "$system_root/tools/generate-catalog.py" --check

# 드리프트를 실제로 잡는지 확인한다. 원본을 건드리지 않도록 복사본에서만 바꾼다.
system_copy="$test_dir/system"
mkdir -p "$system_copy"
(cd "$system_root" && tar --exclude=.git -cf - .) | (cd "$system_copy" && tar -xf -)

sed "s/^    version: 0.1.0-draft$/    version: 9.9.9-drift/" "$system_copy/system.yaml" \
  >"$system_copy/system.yaml.next"
mv "$system_copy/system.yaml.next" "$system_copy/system.yaml"
if python3 "$system_copy/tools/check-consistency.py" >/dev/null 2>&1; then
  printf '%s\n' 'consistency check accepted a package version drift' >&2
  exit 1
fi

(cd "$system_root" && tar --exclude=.git -cf - .) | (cd "$system_copy" && tar -xf -)
printf '%s\n' 'drift' >>"$system_copy/docs/generated/system-catalog.md"
if python3 "$system_copy/tools/generate-catalog.py" --check >/dev/null 2>&1; then
  printf '%s\n' 'generated catalog check accepted a stale document' >&2
  exit 1
fi
