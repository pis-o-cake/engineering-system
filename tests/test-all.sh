#!/bin/sh

set -eu

# 단위 검사는 개발 중인 코드를 실행한다. 버전 고정 검사는 이 변수를 지우고 별도로 검증한다.
export ENGSYS_USE_CHECKOUT=1

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
system_root=$(CDPATH= cd -- "$test_root/.." && pwd)

# fixture 는 자기 임시 저장소에만 써야 한다. 상위에서 흘러든 Git 환경 변수가 남아 있으면
# fixture 의 git 명령이 이 저장소를 대상으로 삼아 config 와 commit 을 남긴다.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_NAMESPACE

# 그런 일이 다시 생기면 조용히 넘어가지 않고 검사를 실패시킨다.
guard=$(mktemp -d)
git -C "$system_root" config --local --list | sort >"$guard/config-before"
git -C "$system_root" rev-parse HEAD >"$guard/head-before"
system_untouched() {
  status=$?
  git -C "$system_root" config --local --list | sort >"$guard/config-after" 2>/dev/null || :
  git -C "$system_root" rev-parse HEAD >"$guard/head-after" 2>/dev/null || :
  if ! cmp -s "$guard/config-before" "$guard/config-after" \
      || ! cmp -s "$guard/head-before" "$guard/head-after"; then
    printf 'a test wrote to the system repository instead of its fixture\n' >&2
    diff "$guard/config-before" "$guard/config-after" >&2 || :
    diff "$guard/head-before" "$guard/head-after" >&2 || :
    rm -rf "$guard"
    exit 1
  fi
  rm -rf "$guard"
  exit "$status"
}
trap system_untouched 0

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
sh "$test_root/test-hook-gate.sh"
sh "$test_root/test-branch-settings.sh"
sh "$test_root/test-merge-request.sh"
sh "$test_root/test-platform-commands.sh"
sh "$test_root/test-install.sh"
"$test_root/test-schema.sh"
"$test_root/test-consistency.sh"
python3 "$test_root/test-documentation.py"
python3 "$test_root/../tools/check-documentation.py"
"$test_root/test-self-contract.sh"
"$test_root/../bin/engsys" docs check --project "$test_root/.."
"$test_root/../bin/engsys" review check --project "$test_root/.."
