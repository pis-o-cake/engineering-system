#!/bin/sh

set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' 0

git -C "$test_dir" init -q
"$system_root/bin/engsys" init --project "$test_dir" \
  --verify 'sh native-check.sh' \
  --generated docs/generated.md 'sh generated-check.sh' >/dev/null

# Removing a package from the old lock gives the upgrade an observable change.
sed '/^  pipeline:$/,/^    revision:/d' "$test_dir/.engsys/lock.yaml" >"$test_dir/old-lock.yaml"
cp "$test_dir/old-lock.yaml" "$test_dir/.engsys/lock.yaml"
printf '%s\n' 'touch native-ran' 'exit 23' >"$test_dir/native-check.sh"
printf '%s\n' 'touch generated-ran' 'exit 24' >"$test_dir/generated-check.sh"

# Preview neither writes the lock nor invokes project-owned commands.
"$system_root/bin/engsys" upgrade --project "$test_dir" >"$test_dir/plan.log"
cmp "$test_dir/old-lock.yaml" "$test_dir/.engsys/lock.yaml"
[ ! -e "$test_dir/native-ran" ]
[ ! -e "$test_dir/generated-ran" ]

upgrade_status=0
"$system_root/bin/engsys" upgrade --project "$test_dir" --apply >"$test_dir/upgrade.log" 2>&1 \
  || upgrade_status=$?
[ "$upgrade_status" -eq 23 ]
[ -f "$test_dir/native-ran" ]
[ ! -e "$test_dir/generated-ran" ]
cmp "$test_dir/old-lock.yaml" "$test_dir/.engsys/lock.yaml"
grep -Fq 'restored the previous lock' "$test_dir/upgrade.log"

# A generated-document failure must also roll back, after native verification.
printf '%s\n' 'touch native-ran' 'exit 0' >"$test_dir/native-check.sh"
upgrade_status=0
"$system_root/bin/engsys" upgrade --project "$test_dir" --apply >"$test_dir/upgrade.log" 2>&1 \
  || upgrade_status=$?
[ "$upgrade_status" -eq 24 ]
[ -f "$test_dir/generated-ran" ]
cmp "$test_dir/old-lock.yaml" "$test_dir/.engsys/lock.yaml"

# Successful verification keeps the new package set and removes transaction files.
printf '%s\n' 'exit 0' >"$test_dir/generated-check.sh"
"$system_root/bin/engsys" upgrade --project "$test_dir" --apply >"$test_dir/upgrade.log" 2>&1
grep -Fq '  pipeline:' "$test_dir/.engsys/lock.yaml"
grep -Fq 'Applied Engineering System upgrade:' "$test_dir/upgrade.log"
for temporary in "$test_dir"/.engsys/lock.yaml.backup.* "$test_dir"/.engsys/lock.yaml.next.*; do
  [ ! -e "$temporary" ]
done
printf '%s\n' 'ok upgrade verifies native and generated checks and restores failed locks'
