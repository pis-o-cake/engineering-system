#!/bin/sh

set -eu

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
"$test_root/test-block-generated-edit.sh"
"$test_root/test-engsys.sh"
"$test_root/test-launcher.sh"
