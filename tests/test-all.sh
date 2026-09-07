#!/bin/sh

set -eu

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
"$test_root/test-block-generated-edit.sh"
"$test_root/test-engsys.sh"
sh "$test_root/test-generated-contract.sh"
"$test_root/test-launcher.sh"
"$test_root/test-schema.sh"
"$test_root/test-consistency.sh"
"$test_root/test-self-contract.sh"
