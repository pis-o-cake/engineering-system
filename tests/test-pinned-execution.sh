#!/bin/sh

# 프로젝트를 검사하는 코드는 그 프로젝트의 lock 이 가리키는 revision 에서 온다.
# 실행한 개발자의 checkout 이 결과를 바꾸면 팀에서 같은 판정을 얻을 수 없다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0
project="$temporary/project"
mkdir -p "$project"
git -C "$project" init -q
"$system_root/bin/engsys" init --project "$project" --verify true >/dev/null 2>&1

run() { ENGSYS_CACHE_DIR="$temporary/cache" "$system_root/bin/engsys" "$@" \
  >"$temporary/out" 2>"$temporary/err"; }

# lock 이 이 checkout 의 commit 이면 그대로 돈다.
run vcs --help --project "$project"
grep -Fq 'check-message' "$temporary/out"

# lock 을 vcs-gov 이전 commit 으로 내리면 그 revision 의 engsys 가 돈다.
adding=$(git -C "$system_root" log --diff-filter=A --format=%H -- packages/vcs-gov/package.yaml \
  | tail -1)
before_vcs=$(git -C "$system_root" rev-parse --verify "$adding^" 2>/dev/null || true)
if [ -n "$before_vcs" ]; then
  sed "s/^\(  *\)revision: .*/\1revision: '$before_vcs'/" "$project/.engsys/lock.yaml" \
    >"$temporary/lock" && cp "$temporary/lock" "$project/.engsys/lock.yaml"

  if run vcs --help --project "$project"; then
    printf 'A revision without vcs-gov must not answer the vcs command\n' >&2
    cat "$temporary/out" "$temporary/err" >&2
    exit 1
  fi
  grep -Fq 'unknown command: vcs' "$temporary/err"

  # 그 revision 에도 있는 명령은 정상으로 끝난다.
  run check --project "$project"
  grep -Fq 'adapter checks passed' "$temporary/out"

  # 개발용 탈출구는 이 checkout 으로 되돌린다.
  ENGSYS_USE_CHECKOUT=1 ENGSYS_CACHE_DIR="$temporary/cache" \
    "$system_root/bin/engsys" vcs --help --project "$project" >"$temporary/out" 2>&1
  grep -Fq 'check-message' "$temporary/out"
else
  printf 'note: vcs-gov 도입 이전 commit 을 찾지 못해 revision 전환 사례를 건너뛴다\n' >&2
fi

# 받을 수 없는 revision 은 작업을 막지 않고 알린다.
sed "s/^\(  *\)revision: .*/\1revision: '0000000000000000000000000000000000000000'/" \
  "$project/.engsys/lock.yaml" >"$temporary/lock" && cp "$temporary/lock" "$project/.engsys/lock.yaml"
run check --project "$project" || true
grep -Fq 'is unavailable; ran this checkout instead' "$temporary/err"

# 시스템 레포 자신은 넘기지 않는다. 표준을 고치는 동안 자기 working tree 로 돌아야 한다.
ENGSYS_CACHE_DIR="$temporary/cache" "$system_root/bin/engsys" vcs --help --project "$system_root" \
  >"$temporary/out" 2>&1
grep -Fq 'check-message' "$temporary/out"

printf 'ok project commands run at the revision the project locked\n'
