#!/bin/sh

set -eu

# 단위 검사는 개발 중인 코드를 실행한다. 버전 고정 검사는 이 변수를 지우고 별도로 검증한다.
export ENGSYS_USE_CHECKOUT=1

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
"$test_root/test-block-generated-edit.sh"
"$test_root/test-engsys.sh"
sh "$test_root/test-line-endings.sh"
sh "$test_root/test-generated-contract.sh"
sh "$test_root/test-upgrade.sh"
sh "$test_root/test-editorial-review.sh"
sh "$test_root/test-document-structure.sh"
sh "$test_root/test-document-feedback.sh"
sh "$test_root/test-document-scaffold.sh"
"$test_root/test-launcher.sh"
sh "$test_root/test-doctor.sh"
sh "$test_root/test-setup.sh"
sh "$test_root/test-hooks-drift.sh"
sh "$test_root/test-contract-scope.sh"
sh "$test_root/test-pinned-execution.sh"
sh "$test_root/test-pushed-commit.sh"
sh "$test_root/test-init-detect.sh"
sh "$test_root/test-commit-message.sh"
sh "$test_root/test-branch-settings.sh"
sh "$test_root/test-platform-commands.sh"
sh "$test_root/test-install.sh"
"$test_root/test-schema.sh"
"$test_root/test-consistency.sh"
python3 "$test_root/test-documentation.py"
python3 "$test_root/../tools/check-documentation.py"
"$test_root/test-self-contract.sh"
"$test_root/../bin/engsys" docs check --project "$test_root/.."
"$test_root/../bin/engsys" review check --project "$test_root/.."
