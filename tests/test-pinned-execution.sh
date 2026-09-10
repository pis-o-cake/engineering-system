#!/bin/sh

# 프로젝트를 검사하는 코드는 그 프로젝트의 lock 이 가리키는 revision 에서 온다.
# 실행한 개발자의 checkout 이 결과를 바꾸면 팀에서 같은 판정을 얻을 수 없다.
set -eu
source_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
unset ENGSYS_USE_CHECKOUT ENGSYS_PINNED ENGSYS_SYSTEM_ROOT
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0
# 실제 checkout 을 고치지 않고 현재 구현을 깨끗한 fixture revision 으로 만든다.
system_root="$temporary/system"
# Windows 는 임시 디렉터리 사이의 hardlink 를 만들지 못한다.
git clone -q --local --no-hardlinks "$source_root" "$system_root"
(cd "$source_root" && tar --exclude=.git -cf - .) | (cd "$system_root" && tar -xf -)
git -C "$system_root" config user.name 'Pinned Fixture'
git -C "$system_root" config user.email 'fixture@example.test'
git -C "$system_root" add -A
git -C "$system_root" -c core.hooksPath=/dev/null commit -q --allow-empty -m 'test: pinned fixture'
project="$temporary/project"
mkdir -p "$project"
git -C "$project" init -q
"$system_root/bin/engsys" init --project "$project" --verify true >/dev/null 2>&1

run() { ENGSYS_CACHE_DIR="$temporary/cache" "$system_root/bin/engsys" "$@" \
  >"$temporary/out" 2>"$temporary/err"; }

# clean checkout 과 lock 이 같으면 그대로 돈다.
run vcs --help --project "$project"
grep -Fq 'check-message' "$temporary/out"

cp "$temporary/out" "$temporary/clean-help"
# HEAD 가 같아도 수정된 usage 가 실행되면 안 된다.
sed 's/check-message/dirty-check-message/g' "$system_root/bin/engsys" >"$temporary/dirty"
cat "$temporary/dirty" >"$system_root/bin/engsys"
run vcs --help --project "$project"
cmp "$temporary/clean-help" "$temporary/out"
revision=$(git -C "$system_root" rev-parse HEAD)
cached="$temporary/cache/releases/$revision"
[ -d "$cached" ]
# 손상된 cache 를 현재 checkout 으로 대체해 성공시키지 않는다.
printf '\n# modified cache\n' >>"$cached/bin/engsys"
if run verify --project "$project"; then
  printf 'a modified cache must fail verification\n' >&2; exit 1
fi
grep -Fq 'could not be prepared' "$temporary/err"
git -C "$cached" checkout -q -- bin/engsys

# engsys claude 도 계약을 lock 이 가리키는 revision 으로 판정한다. 현재 checkout 의 parser 를
# 쓰면 같은 계약에 engsys check 와 반대 답을 내고, 어느 쪽이 유효한지 알 방법이 없어진다.
mkdir -p "$temporary/fake-bin"
printf '#!/bin/sh\nprintf "claude ran\\n"\n' >"$temporary/fake-bin/claude"
chmod +x "$temporary/fake-bin/claude"
# checkout 의 check 만 무조건 통과하게 바꿔 두 판정을 갈라 놓는다. 판정이 갈리지 않으면
# 어느 경로로 돌았는지 이 검사가 구분하지 못한다.
awk '{ print } /^check\(\) \{$/ && !done { print "  printf \"checkout check passed\\n\"; return 0"; done = 1 }' \
  "$system_root/bin/engsys" >"$temporary/lenient"
cat "$temporary/lenient" >"$system_root/bin/engsys"
grep -Fq 'checkout check passed' "$system_root/bin/engsys"
# lock 이 가리키는 revision 은 이 key 를 모른다.
awk '{ print } /^  verify:/ { print "  verify-win: \047true\047" }' \
  "$project/.engsys/project.yaml" >"$temporary/contract"
cp "$temporary/contract" "$project/.engsys/project.yaml"

if PATH="$temporary/fake-bin:$PATH" ENGSYS_CACHE_DIR="$temporary/cache" \
    "$system_root/bin/engsys" claude --project "$project" >"$temporary/out" 2>&1; then
  printf 'engsys claude must judge the contract at the locked revision\n' >&2
  cat "$temporary/out" >&2
  exit 1
fi
grep -Fq 'unknown commands key: verify-win' "$temporary/out"
if grep -Fq 'claude ran' "$temporary/out"; then
  printf 'engsys claude started Claude Code despite a rejected contract\n' >&2
  exit 1
fi

# 경로를 열지 못한 것과 담긴 revision 이 다른 것은 다른 문제다. 하나로 뭉치면 멀쩡한 cache 를
# 지우라고 안내하게 되고, 실제 원인(환경이 경로를 가림)은 끝까지 보이지 않는다.
mv "$cached/.git" "$temporary/cache-git"
printf 'not a worktree link\n' >"$cached/.git"
if run check --project "$project"; then
  printf 'an unreadable cache must fail the check\n' >&2; exit 1
fi
grep -Fq 'could not read the cached revision' "$temporary/err"
if grep -Fq 'cached revision is invalid' "$temporary/err"; then
  printf 'an unreadable path must not be reported as a wrong revision\n' >&2; exit 1
fi
mv -f "$temporary/cache-git" "$cached/.git"

git -C "$system_root" checkout -q -- bin/engsys

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

# 받을 수 없는 revision 은 일반 검사에서도 실패한다. 네트워크에 의존하지 않는다.
git -C "$system_root" remote remove origin
sed "s/^\(  *\)revision: .*/\1revision: '0000000000000000000000000000000000000000'/" \
  "$project/.engsys/lock.yaml" >"$temporary/lock" && cp "$temporary/lock" "$project/.engsys/lock.yaml"
for command in check verify; do
  if run "$command" --project "$project"; then
    printf 'an unavailable revision must fail %s\n' "$command" >&2; exit 1
  fi
  grep -Fq 'could not be prepared' "$temporary/err"
done

# 시스템 레포 자신은 넘기지 않는다. 표준을 고치는 동안 자기 working tree 로 돌아야 한다.
ENGSYS_CACHE_DIR="$temporary/cache" "$system_root/bin/engsys" vcs --help --project "$system_root" \
  >"$temporary/out" 2>&1
grep -Fq 'check-message' "$temporary/out"

printf 'ok project commands run at the revision the project locked\n'
