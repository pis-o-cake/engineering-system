#!/bin/sh

set -eu

source_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)
cleanup() {
  cleanup_status=$?
  rm -rf "$test_dir"
  trap - 0 1 2 15
  exit "$cleanup_status"
}
trap cleanup 0 1 2 15

system_copy="$test_dir/system"
project_dir="$test_dir/project"
fake_bin="$test_dir/fake-bin"
git clone -q "$source_root" "$system_copy"
cp "$source_root/bin/engsys" "$system_copy/bin/engsys"
git -C "$system_copy" config user.email fixture@example.test
git -C "$system_copy" config user.name fixture
git -C "$system_copy" add bin/engsys
git -C "$system_copy" commit -qm 'test: launcher source 갱신'

mkdir -p "$project_dir"
git -C "$project_dir" init -q
ENGSYS_SYSTEM_ROOT="$system_copy" "$system_copy/bin/engsys" init \
  --project "$project_dir" \
  --name launcher-fixture \
  --verify 'printf project-verification'

shellenv=$(ENGSYS_SYSTEM_ROOT="$system_copy" "$system_copy/bin/engsys" shellenv)
printf '%s\n' "$shellenv" | grep -Fq "export PATH='$system_copy/bin':"

resolved=$(ENGSYS_SYSTEM_ROOT="$system_copy" ENGSYS_CACHE_DIR="$test_dir/cache" \
  "$system_copy/bin/engsys" resolve --project "$project_dir")
[ "$resolved" = "$system_copy" ]

mkdir -p "$fake_bin"
printf '%s\n' '#!/bin/sh' 'printf "%s\\n" "$@"' >"$fake_bin/claude"
chmod +x "$fake_bin/claude"
launch_output=$(PATH="$fake_bin:$PATH" ENGSYS_SYSTEM_ROOT="$system_copy" \
  ENGSYS_CACHE_DIR="$test_dir/cache" "$system_copy/bin/engsys" claude --project "$project_dir" --resume)
printf '%s\n' "$launch_output" | grep -Fxq -- '--plugin-dir'
printf '%s\n' "$launch_output" | grep -Fxq -- "$system_copy"
printf '%s\n' "$launch_output" | grep -Fxq -- '--resume'

source_revision=$(git -C "$source_root" rev-parse HEAD)
awk -v revision="$source_revision" '
  !changed && /^  revision:/ { print "  revision: '\''" revision "'\''"; changed = 1; next }
  { print }
' "$project_dir/.engsys/lock.yaml" >"$project_dir/.engsys/lock.yaml.next"
mv "$project_dir/.engsys/lock.yaml.next" "$project_dir/.engsys/lock.yaml"
cached=$(ENGSYS_SYSTEM_ROOT="$system_copy" ENGSYS_CACHE_DIR="$test_dir/cache" \
  "$system_copy/bin/engsys" resolve --project "$project_dir")
[ "$cached" = "$test_dir/cache/releases/$source_revision" ]
[ "$(git -C "$cached" rev-parse HEAD)" = "$source_revision" ]
