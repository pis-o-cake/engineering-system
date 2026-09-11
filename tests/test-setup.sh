#!/bin/sh

# 채택은 단계마다 무엇이 바뀌는지 보여 주고 동의를 받는다. 확인 없이 쓰지 않는다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0
# doctor 는 활성화한 개발자를 전제한다. fixture 도 launcher 를 PATH 에 두어
# 개발자가 install.sh 를 돌렸는지에 결과가 달라지지 않게 한다.
PATH="$system_root/bin:$PATH"
export PATH

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
grep -Fq '터미널이 없어 단계마다 물어볼 수 없다' "$temporary/out"
[ ! -e "$project/.engsys" ]

# --yes 는 모든 단계를 승인한다. 계약을 만들기 전에 먼저 보여 준다.
setup --yes
expect '[1] 전제 도구'
expect '[4] 대상 프로젝트'
expect '미리보기, 쓰지 않음'
expect 'detected verify command: make check'
expect 'detected branch model: env-branch'
expect 'Nothing was written'
expect '[7] 프로젝트 개발 환경'
expect '[8] 검증'
expect '[9] 최종 진단'
expect '[10] 남은 것'
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

# 시스템 저장소 자신을 대상으로 잡으면 무엇을 해야 하는지 알린다.
if (cd "$system_root" && "$system_root/bin/engsys" setup --yes) \
    >"$temporary/out" 2>"$temporary/err"; then
  printf 'setup must refuse to target the standard repository itself\n' >&2
  exit 1
fi
grep -Fq '대상이 표준 저장소 자신이다' "$temporary/out"

# 실패하면 어디서 멈췄는지와 다음에 무엇을 할지 남긴다. 한 줄만 찍고 끝나지 않는다.
mkdir -p "$temporary/notgit"
if "$system_root/bin/engsys" setup --project "$temporary/notgit" --yes \
    >"$temporary/out" 2>&1; then
  printf 'setup must fail for a directory that is not a Git worktree\n' >&2
  exit 1
fi
grep -Fq '멈춘 곳: [4] 대상 프로젝트' "$temporary/out"
grep -Fq '지금 상태 보기 : engsys doctor' "$temporary/out"
grep -Fq '다시 실행      : engsys setup' "$temporary/out"
log=$(sed -n 's/.*전체 기록      : //p' "$temporary/out" | sed -n '1p')
[ -s "$log" ] || { printf 'setup must leave a transcript at %s\n' "$log" >&2; exit 1; }
grep -Fq '[1] 전제 도구' "$log"
rm -f "$log"

# 마지막 진단에서 남은 문제가 있으면 성공으로 끝내지 않는다.
sed "s/^\\( *\\)revision: .*/\\1revision: '0000000000000000000000000000000000000000'/" \
  "$project/.engsys/lock.yaml" >"$temporary/lock"
cp "$temporary/lock" "$project/.engsys/lock.yaml"
if "$system_root/bin/engsys" setup --project "$project" --yes >"$temporary/out" 2>&1; then
  printf 'setup must not report success while doctor still reports a failure\n' >&2
  cat "$temporary/out" >&2
  exit 1
fi
grep -Fq '멈춘 곳: [9] 최종 진단' "$temporary/out"
grep -Fq '위 FAIL 항목이 남아 있다' "$temporary/out"

printf 'ok setup checks each step before it changes anything\n'
