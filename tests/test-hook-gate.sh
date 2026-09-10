#!/bin/sh

# commit-msg gate 는 engsys 가 죽으면 열린다. "이 engsys 에는 subcommand 가 없다" 와
# "engsys 가 오류로 죽었다" 를 구분하지 않으면 규약 위반 commit 이 조용히 들어온다.
set -eu
source_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
unset ENGSYS_USE_CHECKOUT ENGSYS_PINNED ENGSYS_SYSTEM_ROOT
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0

fail() { printf '%s\n' "$1" >&2; [ ! -f "$temporary/out" ] || cat "$temporary/out" >&2; exit 1; }

# lock 이 가리키는 revision 을 cache 에서 꺼내 쓰는 경로를 실제로 태운다. checkout 과 lock 이
# 같으면 early return 으로 빠져 이 결함이 보이지 않는다.
system_root="$temporary/system"
# Windows 는 임시 디렉터리 사이의 hardlink 를 만들지 못한다.
git clone -q --local --no-hardlinks "$source_root" "$system_root"
(cd "$source_root" && tar --exclude=.git -cf - .) | (cd "$system_root" && tar -xf -)
git -C "$system_root" config user.name 'Hook Gate Fixture'
git -C "$system_root" config user.email 'fixture@example.test'
git -C "$system_root" add -A
git -C "$system_root" -c core.hooksPath=/dev/null commit -q --allow-empty -m 'test: hook gate fixture'

project="$temporary/project"
mkdir -p "$project"
git -C "$project" init -q
git -C "$project" config user.name 'Hook Gate Fixture'
git -C "$project" config user.email 'fixture@example.test'
"$system_root/bin/engsys" init --project "$project" --verify true --hooks >/dev/null 2>&1
cat >>"$project/.engsys/project.yaml" <<'EOF'

vcs:
  commit:
    subject-language: 'ko'
    subject-ending: 'noun'
    scopes:
      - 'auth'
EOF

# checkout 이 lock 과 어긋난 상태 — upgrade 가 필요한 바로 그 상태 — 를 만든다.
# 이때만 cache worktree 를 꺼내 쓰는 경로를 탄다.
printf '\n# working tree drift\n' >>"$system_root/README.md"

# launcher 를 PATH 에 두고, cache 는 fixture 안에 가둔다.
bin="$temporary/bin"
mkdir -p "$bin"
cat >"$bin/engsys" <<EOF
#!/bin/sh
exec "$system_root/bin/engsys" "\$@"
EOF
chmod +x "$bin/engsys"
PATH="$bin:$PATH"
export PATH
ENGSYS_CACHE_DIR="$temporary/cache"
export ENGSYS_CACHE_DIR

commit() { (cd "$project" && git commit -q --allow-empty -m "$1") >"$temporary/out" 2>&1; }

# git 은 hook 에 GIT_INDEX_FILE 을 상대 경로로 넘긴다. engsys 가 그걸 지우지 않으면 자기
# cache worktree 를 호출자의 index 로 읽어 죽고, gate 는 그 죽음을 낡은 engsys 로 오독한다.
if commit 'bad message with no type'; then
  fail 'a message that violates the contract was committed'
fi
grep -Fq '형식이 아니다' "$temporary/out" || fail 'the gate rejected for the wrong reason'

commit 'feat(auth): 로그인 게이트 추가' || fail 'a conforming message was rejected'

# engsys 가 다른 이유로 죽으면 통과시키지 않는다.
cat >"$bin/engsys" <<'EOF'
#!/bin/sh
printf 'engsys: cached revision has local changes\n' >&2
exit 1
EOF
if commit 'still a bad message'; then
  fail 'a broken engsys opened the commit gate'
fi
grep -Fq 'failed before the commit message contract' "$temporary/out" \
  || fail 'the gate did not report why it could not check'

# subcommand 자체가 없는 낡은 engsys 만 건너뛴다.
cat >"$bin/engsys" <<'EOF'
#!/bin/sh
printf 'engsys: unknown command: vcs\n' >&2
exit 1
EOF
commit 'old engsys passes through' || fail 'an engsys without the subcommand must not block the commit'
grep -Fq 'has no vcs check-message' "$temporary/out" || fail 'the skip was not announced'

printf 'ok the commit gate closes when the checker cannot run\n'
