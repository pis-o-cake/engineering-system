#!/bin/sh

# 선언한 block 이 파싱되지 않으면 검사가 조용히 0건으로 통과한다. 그 상태를 오류로 잡는다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0

new_project() {
  project="$temporary/$1"
  mkdir -p "$project/docs"
  git -C "$project" init -q
  "$system_root/bin/engsys" init --project "$project" --verify true >/dev/null 2>&1
  shift
  printf '%s\n' "$@" >>"$project/.engsys/project.yaml"
}
reject() {
  if "$system_root/bin/engsys" check --project "$project" >"$temporary/out" 2>"$temporary/err"; then
    printf 'Unexpected acceptance: %s\n' "$1" >&2; cat "$temporary/out" >&2; exit 1
  fi
  grep -Fq "$2" "$temporary/err" || {
    printf 'Missing reason for %s: %s\n' "$1" "$2" >&2; cat "$temporary/err" >&2; exit 1
  }
}

# 들여쓰기를 잘못 쓴 assign 은 파싱되지 않는다. 이전에는 0건으로 통과했다.
new_project bad-assign '  authoring:' '    assign:' '    - path: '"'"'docs'"'"'' \
  '      type: '"'"'guide'"'"''
reject 'assign at the wrong indentation' 'documentation.authoring is declared but no entry was read'

new_project bad-review '  review:' '    scopes:' '    - '"'"'docs'"'"''
reject 'scopes at the wrong indentation' 'documentation.review is declared but no entry was read'

new_project bad-vcs 'vcs:' '  branch:' '  model: '"'"'single-main'"'"''
reject 'branch fields at the wrong indentation' 'vcs.branch is declared but no entry was read'

# 올바른 선언은 통과한다.
new_project good '  authoring:' '    assign:' '      - path: '"'"'docs'"'"'' \
  '        type: '"'"'guide'"'"'' '  review:' '    scopes:' '      - '"'"'docs'"'"''
"$system_root/bin/engsys" check --project "$project" >/dev/null

# 검사 범위 표시: 배정·유예·제외·미배정을 함께 센다.
printf -- '---\ntype: guide\nstatus: active\n---\n\n# 문서\n\n여기서 시작한다.\n' \
  >"$project/docs/README.md"
printf '# 배정 밖\n' >"$project/loose.md"
"$system_root/bin/engsys" docs check --project "$project" >"$temporary/out" 2>&1
grep -Eq '유형 미배정 [1-9]' "$temporary/out"
grep -Fq '유형 미배정: loose.md' "$temporary/out"

printf 'ok the contract check names what it did not read\n'
