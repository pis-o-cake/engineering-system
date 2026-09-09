#!/bin/sh

# 역할과 접두사는 프로젝트가 이름을 정한다. 도구는 그 선언을 읽고 이름을 하드코딩하지 않는다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0

new_project() {
  project="$temporary/$1"
  mkdir -p "$project"
  git -C "$project" init -q
  "$system_root/bin/engsys" init --project "$project" --verify true >/dev/null 2>&1
  shift
  printf '%s\n' "$@" >>"$project/.engsys/project.yaml"
  python3 "$system_root/tools/validate-contract.py" project "$project/.engsys/project.yaml" >/dev/null
}
vcs() { "$system_root/bin/engsys" vcs "$@" --project "$project" >"$temporary/out" 2>"$temporary/err"; }
expect_out() {
  grep -Fq "$1" "$temporary/out" || {
    printf 'Expected %s\n' "$1" >&2; cat "$temporary/out" "$temporary/err" >&2; exit 1
  }
}
expect_fail() {
  if vcs check-settings; then
    printf 'Unexpected success: %s\n' "$1" >&2; cat "$temporary/out" >&2; exit 1
  fi
  grep -Fq "$2" "$temporary/err" || {
    printf 'Missing reason for %s: %s\n' "$1" "$2" >&2; cat "$temporary/err" >&2; exit 1
  }
}

# 선언을 추가하지 않은 프로젝트는 계약 기본값으로 동작한다.
new_project defaults 'vcs:' '  branch:' "    model: 'env-branch'"
vcs check-settings
vcs settings; expect_out 'role	development	develop'; expect_out 'role	production	main'
vcs base-branch --branch feat/x; grep -Fxq develop "$temporary/out"
vcs base-branch --branch hotfix/x; grep -Fxq main "$temporary/out"

# 이름을 바꾸면 같은 도구가 그 이름을 쓴다.
new_project renamed 'vcs:' '  branch:' "    model: 'env-branch'" '    roles:' \
  "      - role: 'development'" "        branch: 'dev'" \
  "      - role: 'production'" "        branch: 'prod'" \
  '    prefixes:' "      feature: 'feature/'" "      hotfix: 'emergency/'" \
  '    protected:' "      - 'dev'" "      - 'prod'"
vcs check-settings
vcs base-branch --branch feature/x; grep -Fxq dev "$temporary/out"
vcs base-branch --branch emergency/x; grep -Fxq prod "$temporary/out"
# 이름 규칙을 선언하지 않았으므로 이름 검사는 하지 않는다.
vcs check-branch --branch anything

# 환경이 셋이면 승격 순서가 선언 순서다.
new_project staged 'vcs:' '  branch:' "    model: 'env-branch'" '    roles:' \
  "      - role: 'development'" "        branch: 'develop'" \
  "      - role: 'staging'" "        branch: 'staging'" \
  "      - role: 'production'" "        branch: 'main'"
vcs check-settings
vcs base-branch --branch feat/x; grep -Fxq develop "$temporary/out"
vcs base-branch --branch hotfix/x; grep -Fxq main "$temporary/out"

# single-main 은 development 역할을 요구하지도, 허용하지도 않는다.
new_project single 'vcs:' '  branch:' "    model: 'single-main'"
vcs check-settings
vcs settings; expect_out 'role	production	main'
if grep -Fq 'development' "$temporary/out"; then
  printf 'single-main must not carry a development role\n' >&2; exit 1
fi
vcs base-branch --branch hotfix/x; grep -Fxq main "$temporary/out"

new_project single-extra 'vcs:' '  branch:' "    model: 'single-main'" '    roles:' \
  "      - role: 'development'" "        branch: 'develop'" \
  "      - role: 'production'" "        branch: 'main'"
expect_fail 'single-main with a development role' '역할을 쓰지 않는다'

# 필수 역할 누락, 알 수 없는 model, 이름 충돌, protected 누락, MR 대상 불일치.
new_project missing-role 'vcs:' '  branch:' "    model: 'env-branch'" '    roles:' \
  "      - role: 'production'" "        branch: 'main'"
expect_fail 'missing development role' 'development 역할을 요구한다'

new_project unknown-model 'vcs:' '  branch:' "    model: 'gitflow'"
expect_fail 'unknown model' '알 수 없는 model'

new_project duplicate 'vcs:' '  branch:' "    model: 'env-branch'" '    roles:' \
  "      - role: 'development'" "        branch: 'main'" \
  "      - role: 'production'" "        branch: 'main'"
expect_fail 'duplicate branch' '같은 branch 를 가리킨다'

new_project unprotected 'vcs:' '  branch:' "    model: 'env-branch'" '    protected:' "      - 'main'"
expect_fail 'role branch missing from protected' 'protected 에 없다'

new_project bad-target 'vcs:' '  branch:' "    model: 'env-branch'" \
  '  merge-request:' "    target: 'release'"
expect_fail 'target outside the roles' '역할 branch 가 아니다'

new_project bad-prefix 'vcs:' '  branch:' "    model: 'env-branch'" '    prefixes:' \
  "      feature: 'feat'"
expect_fail 'prefix without a slash' '/ 로 끝나야 한다'

printf 'ok branch roles and prefixes come from the project declaration\n'
