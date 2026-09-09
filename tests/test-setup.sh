#!/bin/sh

# 채택은 단계마다 무엇이 바뀌는지 보여 주고 동의를 받는다. 확인 없이 쓰지 않는다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0
project="$temporary/project"
mkdir -p "$project/backend"
git -C "$project" init -q
printf 'check:\n\techo ok\n' >"$project/Makefile"
git -C "$project" add -A
git -C "$project" -c user.email=t@t -c user.name=t commit -qm 'chore: 기준선'
git -C "$project" branch develop

setup() { "$system_root/bin/engsys" setup --project "$project" "$@" \
  >"$temporary/out" 2>"$temporary/err"; }
expect() {
  grep -Fq "$1" "$temporary/out" || {
    printf 'Expected %s\n' "$1" >&2; cat "$temporary/out" "$temporary/err" >&2; exit 1
  }
}

# 터미널도 --yes 도 없으면 묻지 못하므로 쓰지 않고 멈춘다.
if setup </dev/null; then
  printf 'setup must not proceed when it cannot ask\n' >&2
  exit 1
fi
grep -Fq '터미널이 없어 단계마다 물어볼 수 없다' "$temporary/err"
[ ! -e "$project/.engsys" ]

# --yes 는 모든 단계를 승인한다. 계약을 만들기 전에 먼저 보여 준다.
setup --yes
expect '[1] 전제 도구'
expect '[4] 대상 프로젝트'
expect '미리보기, 쓰지 않음'
expect 'detected verify command: make check'
expect 'detected branch model: env-branch'
expect 'Nothing was written'
expect '[7] 남은 것'
[ -f "$project/.engsys/project.yaml" ]
[ -x "$project/.githooks/commit-msg" ]
[ "$(git -C "$project" config --get core.hooksPath)" = .githooks ]

# 다시 돌려도 계약을 새로 만들지 않는다.
before=$(git -C "$project" hash-object -- "$project/.engsys/project.yaml")
setup --yes
expect '계약이 이미 있다'
[ "$(git -C "$project" hash-object -- "$project/.engsys/project.yaml")" = "$before" ]

# 프로젝트가 고친 hook 은 갱신 단계에서 덮지 않는다.
printf '\n# 이 프로젝트만의 검사\n' >>"$project/.githooks/pre-push"
edited=$(git -C "$project" hash-object -- "$project/.githooks/pre-push")
setup --yes
[ "$(git -C "$project" hash-object -- "$project/.githooks/pre-push")" = "$edited" ]
expect 'pre-push: modified'

# Git worktree 가 아니면 시작하지 않는다.
mkdir -p "$temporary/plain"
if "$system_root/bin/engsys" setup --project "$temporary/plain" --yes \
    >"$temporary/out" 2>"$temporary/err"; then
  printf 'setup must refuse a directory that is not a Git worktree\n' >&2
  exit 1
fi
grep -Fq 'not a Git worktree' "$temporary/err"

printf 'ok setup checks each step before it changes anything\n'
