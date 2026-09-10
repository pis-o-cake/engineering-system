#!/bin/sh

# merge request 본문은 git 안에 없어서 hook 지점이 없다. 그래서 오래 선언만 있고 판정이
# 없었다. 판정은 명령이 하고, gate 는 저장소에 든 설정이 부른다 — 세션이 무엇을 읽었는지와
# 무관하게 돌아야 한다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0
project="$temporary/project"
mkdir -p "$project"
git -C "$project" init -q
"$system_root/bin/engsys" init --project "$project" --verify true >/dev/null 2>&1
cat >>"$project/.engsys/project.yaml" <<'EOF'

vcs:
  commit:
    subject-language: 'ko'
    subject-ending: 'noun'
    scopes:
      - 'auth'
  branch:
    model: 'single-main'
    roles:
      - role: 'production'
        branch: 'main'
  merge-request:
    target: 'main'
EOF

body="$temporary/body.md"
check() { "$system_root/bin/engsys" vcs check-merge-request "$body" --project "$project" "$@" \
  >"$temporary/out" 2>"$temporary/err"; }
reject() {
  if check; then
    printf 'Unexpected acceptance: %s\n' "$1" >&2; exit 1
  fi
  grep -Fq "$2" "$temporary/err" || {
    printf 'Missing reason for %s: %s\n' "$1" "$2" >&2; cat "$temporary/err" >&2; exit 1
  }
}

good() {
  cat >"$body" <<'EOF'
## 요약

한 문장으로 적는다.

## 변경 사항

- 하나를 바꾼다

## 검증

- `sh tests/test-merge-request.sh` 통과

## 영향 및 후속 작업

없음
EOF
}

# 선언한 절이 순서대로 있고 내용이 있으면 통과한다.
good
check || { printf 'A conforming body was rejected\n' >&2; cat "$temporary/err" >&2; exit 1; }

# 절이 빠지면 막는다.
good
grep -v '^## 검증$' "$body" >"$temporary/next" && cp "$temporary/next" "$body"
reject 'missing section' '절이 없다: ## 검증'

# 선언 밖의 절 제목은 쓰지 않는다.
good
printf '\n## 배경\n\n어쩌고\n' >>"$body"
reject 'undeclared heading' '선언하지 않은 절 제목이다: ## 배경'

# 절 제목만 있고 내용이 없으면 검토했는지 알 수 없다.
good
awk '/^## 영향 및 후속 작업$/ { print; exit } { print }' "$body" >"$temporary/next"
cp "$temporary/next" "$body"
reject 'empty section' '절이 비어 있다: ## 영향 및 후속 작업'

# 순서가 다르면 막는다.
cat >"$body" <<'EOF'
## 변경 사항

- 하나

## 요약

한 문장이다.

## 검증

- 돌렸다

## 영향 및 후속 작업

없음
EOF
reject 'wrong order' '절 순서가 계약과 다르다'

# 자동 생성 서명과 도구 표기는 본문에 넣지 않는다.
good
printf '\n🤖 Generated with Claude Code\n' >>"$body"
reject 'generated signature' '자동 생성 서명은 본문에 넣지 않는다'

# title 은 commit 헤더와 같은 형식이다.
good
if check --title 'PR 제목 아무렇게나'; then
  printf 'A title outside the commit header form must be rejected\n' >&2; exit 1
fi
grep -Fq 'title 이 commit 헤더 형식이 아니다' "$temporary/err"
good
check --title 'fix(auth): 로그인 게이트 추가' \
  || { printf 'A conforming title was rejected\n' >&2; cat "$temporary/err" >&2; exit 1; }

# merge-request 를 선언하지 않은 프로젝트는 판정 대상이 아니다.
plain="$temporary/plain"
mkdir -p "$plain"
git -C "$plain" init -q
"$system_root/bin/engsys" init --project "$plain" --verify true >/dev/null 2>&1
printf '## 아무 제목\n' >"$body"
"$system_root/bin/engsys" vcs check-merge-request "$body" --project "$plain" >/dev/null 2>&1

# --- gate ---
# init 이 저장소에 표준을 가리키는 선언을 남긴다. gate 는 그 plugin 이 나른다. skill 을 읽었는지와
# 무관하게, 그리고 PATH 가 비어 있어도 돌아야 한다.
grep -Fq 'enabledPlugins' "$project/.claude/settings.json"
grep -Fq 'check-merge-request.sh' "$system_root/adapters/claude-code/hooks/catalog.json"

hook() { "$system_root/bin/engsys" vcs merge-request-hook <"$temporary/payload" \
  >"$temporary/out" 2>"$temporary/err"; }
payload() {
  printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}\n' "$project" "$1" \
    >"$temporary/payload"
}
denied() {
  hook
  grep -Fq '"permissionDecision":"deny"' "$temporary/out" || {
    printf 'The gate let this through: %s\n' "$1" >&2; cat "$temporary/out" >&2; exit 1
  }
  grep -Fq "$2" "$temporary/out" || {
    printf 'Missing reason for %s: %s\n' "$1" "$2" >&2; cat "$temporary/out" >&2; exit 1
  }
}
allowed() {
  hook
  if grep -Fq 'permissionDecision' "$temporary/out"; then
    printf 'The gate blocked this: %s\n' "$1" >&2; cat "$temporary/out" >&2; exit 1
  fi
}

# gh 와 무관한 명령은 건드리지 않는다.
payload 'ls -la'
allowed 'unrelated command'

# 명령 자리에 있는 gh 만 본다. commit 메시지나 문서 본문에 같은 글자가 있다고 그것을
# 실행하는 것은 아니다. 이 gate 자체를 설명하는 커밋이 이 오탐에 걸렸다.
printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"git commit -F - <<MSG\\nfeat: x\\n\\ngh pr create \\uc55e\\uc5d0\\uc11c \\ubd80\\ub978\\ub2e4. inline --body \\ub294 \\ub9c9\\ub294\\ub2e4.\\nMSG"}}\n' \
  "$project" >"$temporary/payload"
allowed 'gh inside a heredoc'

# 읽을 수 없는 본문은 통과시키지 않는다. 판정은 읽은 것에만 할 수 있다.
payload 'gh pr create --title x --body \"대충 씀\"'
denied 'inline body' 'not inline --body'

payload 'gh pr create --title x'
denied 'no body at all' 'needs --body-file'

# 본문이 계약을 지키면 통과하고, 어기면 그 이유를 돌려준다.
good
payload "gh pr create --body-file $body"
allowed 'conforming body'

printf '\n## 배경\n\n어쩌고\n' >>"$body"
payload "gh pr create --body-file $body"
denied 'undeclared heading through the gate' '선언하지 않은 절 제목'

# 같은 명령에서 세운 변수는 hook 프로세스의 환경에 없다. 그것 때문에 정상 명령을 막으면
# 사람은 gate 를 우회할 방법부터 찾는다.
good
printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"OUT=%s\\ngh pr create --body-file \\"$OUT/body.md\\""}}\n' \
  "$project" "$temporary" >"$temporary/payload"
allowed 'a path built from an assignment in the same command'

# 대입해 둔 변수라도 값이 계약을 어긴 본문을 가리키면 그대로 막는다.
printf '\n## 배경\n\n어쩌고\n' >>"$body"
printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"OUT=%s\\ngh pr create --body-file \\"$OUT/body.md\\""}}\n' \
  "$project" "$temporary" >"$temporary/payload"
denied 'a resolved path still gets judged' '선언하지 않은 절 제목'

# 값을 알 수 없는 변수는 풀지 않는다. 읽지 못한 본문을 통과시키지 않는다.
printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"D=$(mktemp -d)\\ngh pr create --body-file \\"$D/body.md\\""}}\n' \
  "$project" >"$temporary/payload"
denied 'a path from command substitution' 'body file does not exist'

# Claude Code 는 이 hook 을 plugin 경로로 직접 부른다. 그때 ENGSYS_SYSTEM_ROOT 는 없고, 로그인
# 셸이 아니라 PATH 에 engsys 가 없을 수 있다. 그래도 자기가 실려 온 plugin 으로 판정해야 한다.
gate="$system_root/packages/vcs-gov/claude-code/hooks/check-merge-request.sh"
good
payload "gh pr create --body-file $body"
CLAUDE_PLUGIN_ROOT="$system_root" PATH="/usr/bin:/bin" ENGSYS_USE_CHECKOUT=1 \
  sh "$gate" <"$temporary/payload" >"$temporary/out" 2>"$temporary/err" \
  || fail 'the hook failed when invoked from the plugin without PATH'
if grep -Fq 'permissionDecision' "$temporary/out"; then
  printf 'the gate must judge a conforming body with the plugin it shipped in\n' >&2
  cat "$temporary/out" >&2
  exit 1
fi

printf '\n## 배경\n\n어쩌고\n' >>"$body"
CLAUDE_PLUGIN_ROOT="$system_root" PATH="/usr/bin:/bin" ENGSYS_USE_CHECKOUT=1 \
  sh "$gate" <"$temporary/payload" >"$temporary/out" 2>"$temporary/err" \
  || fail 'the hook failed when invoked from the plugin without PATH'
grep -Fq '선언하지 않은 절 제목' "$temporary/out" \
  || fail 'the plugin-invoked gate did not judge the body'

# 어디서도 찾지 못하면 조용히 넘기지 않고 그 사실을 돌려준다.
PATH="/usr/bin:/bin" sh "$gate" <"$temporary/payload" >"$temporary/out" 2>&1 || true
grep -Fq 'could not find engsys' "$temporary/out" \
  || fail 'a hook that cannot find engsys must say so, not pass silently'

# 계약을 선언하지 않은 프로젝트에서는 gate 가 돌지 않는다.
printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"gh pr create --title x"}}\n' \
  "$plain" >"$temporary/payload"
allowed 'a project without a vcs declaration'

printf 'ok merge request bodies are judged by a gate, not by a session instruction\n'
