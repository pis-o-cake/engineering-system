#!/bin/sh

# gate 는 전송할 commit 을 판정해야 한다. working tree 를 검사하고 다른 commit 을 통과시키면
# gate 가 있으나 없으나 같다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0
project="$temporary/project"
mkdir -p "$project"
git -C "$project" init -q
git -C "$project" config user.name 'Pushed Fixture'
git -C "$project" config user.email 'fixture@example.test'
printf '#!/bin/sh\ngrep -q good value.txt\n' >"$project/check.sh"
chmod +x "$project/check.sh"
printf 'good\n' >"$project/value.txt"
git -C "$project" add -A
git -C "$project" commit -qm 'chore: 기준선'
"$system_root/bin/engsys" init --project "$project" --verify './check.sh' --hooks >/dev/null 2>&1
git -C "$project" add -A
git -C "$project" commit -qm 'build: 계약 추가'

verify() { "$system_root/bin/engsys" verify --project "$project" "$@" \
  >"$temporary/out" 2>"$temporary/err"; }

# 깨끗한 tree 에서는 commit 을 판정한다.
head=$(git -C "$project" rev-parse HEAD)
verify --revision "$head"
grep -Fq "Verifying commit $head" "$temporary/out"
grep -Fq 'Engineering System revision:' "$temporary/out"

# commit 에는 실패할 값이, working tree 에는 통과할 값이 있는 상태.
printf 'bad\n' >"$project/value.txt"
git -C "$project" add value.txt
git -C "$project" commit -qm 'chore: 잘못된 값 commit'
head=$(git -C "$project" rev-parse HEAD)
printf 'good\n' >"$project/value.txt"

# --revision 없이는 working tree 를 검사하므로 통과한다. 그것이 이 명령의 뜻이다.
verify
grep -Fq 'verification passed' "$temporary/out"

# --revision 을 주면 검사 대상이 그 commit 이 아니라는 것을 먼저 잡는다.
if verify --revision "$head"; then
  printf 'verify --revision must refuse a working tree that is not the commit\n' >&2
  exit 1
fi
grep -Fq 'the working tree is not' "$temporary/err"
grep -Fq 'changed  value.txt' "$temporary/err"

# 기본 pre-push 도 같은 이유로 막는다. 이것이 고치기 전 거짓 통과가 나던 경로다.
printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' "$head" \
  >"$temporary/refs"
if (cd "$project" && PATH="$system_root/bin:$PATH" /bin/sh .githooks/pre-push <"$temporary/refs") \
    >"$temporary/out" 2>"$temporary/err"; then
  printf 'the default pre-push must refuse to judge a tree that is not the pushed commit\n' >&2
  cat "$temporary/out" "$temporary/err" >&2
  exit 1
fi

# untracked 파일도 commit 과의 차이다. 그 파일이 있어야 통과하는 검사를 걸러내지 못한다.
git -C "$project" checkout -q -- value.txt
printf 'x\n' >"$project/extra.txt"
if verify --revision "$head"; then
  printf 'an untracked file is still a difference from the pushed commit\n' >&2
  exit 1
fi
grep -Fq 'untracked  extra.txt' "$temporary/err"
rm "$project/extra.txt"
verify --revision "$head" || true

# check 도 같은 단언을 제공한다. 자체 검사를 직접 부르는 프로젝트 hook 이 verify 전체를 다시
# 돌리지 않고 대상만 확인할 수 있어야 한다.
check_only() { "$system_root/bin/engsys" check --project "$project" "$@" \
  >"$temporary/out" 2>"$temporary/err"; }
printf 'good\n' >"$project/value.txt"
if check_only --revision "$head"; then
  printf 'check --revision must refuse a working tree that is not the commit\n' >&2
  exit 1
fi
grep -Fq 'the working tree is not' "$temporary/err"
git -C "$project" checkout -q -- value.txt
check_only --revision "$head"
grep -Fq "Checking commit $head" "$temporary/out"
grep -Fq 'adapter checks passed' "$temporary/out"

printf 'ok the push gate judges the commit it sends\n'
