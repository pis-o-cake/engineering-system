#!/bin/sh

set -eu

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
"$test_root/test-block-generated-edit.sh"
"$test_root/test-engsys.sh"
sh "$test_root/test-generated-contract.sh"
sh "$test_root/test-upgrade.sh"
sh "$test_root/test-editorial-review.sh"
sh "$test_root/test-document-structure.sh"
"$test_root/test-launcher.sh"
sh "$test_root/test-doctor.sh"
sh "$test_root/test-init-detect.sh"
sh "$test_root/test-install.sh"
"$test_root/test-schema.sh"
"$test_root/test-consistency.sh"
python3 "$test_root/test-documentation.py"
python3 "$test_root/../tools/check-documentation.py"
"$test_root/test-self-contract.sh"
"$test_root/../bin/engsys" docs check --project "$test_root/.."
"$test_root/../bin/engsys" review check --project "$test_root/.."
