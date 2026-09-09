#!/bin/sh

# 계약은 시스템이, 값은 프로젝트가 갖는다. 기계가 판정할 수 있는 것만 막고 나머지는 알린다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0
project="$temporary/project"
mkdir -p "$project"
git -C "$project" init -q
"$system_root/bin/engsys" init --project "$project" --verify true >/dev/null 2>&1

message="$temporary/message"
check() { "$system_root/bin/engsys" vcs check-message "$message" --project "$project" \
  >"$temporary/out" 2>"$temporary/err"; }
accept() {
  printf '%s' "$1" >"$message"
  if ! check; then
    printf 'Unexpected rejection: %s\n' "$1" >&2
    cat "$temporary/err" >&2
    exit 1
  fi
}
reject() {
  printf '%s' "$1" >"$message"
  if check; then
    printf 'Unexpected acceptance: %s\n' "$1" >&2
    exit 1
  fi
  grep -Fq "$2" "$temporary/err" || {
    printf 'Missing reason for %s: %s\n' "$1" "$2" >&2
    cat "$temporary/err" >&2
    exit 1
  }
}

# vcs 선언이 없는 프로젝트는 검사 대상이 아니다.
accept 'garbage that satisfies nothing'

cat >>"$project/.engsys/project.yaml" <<'EOF'

vcs:
  commit:
    subject-language: 'ko'
    subject-ending: 'noun'
    scopes:
      - 'auth'
      - 'chat'
EOF
python3 "$system_root/tools/validate-contract.py" project "$project/.engsys/project.yaml" >/dev/null
"$system_root/bin/engsys" check --project "$project" >/dev/null

accept 'fix(chat): 답변 마크다운 렌더링 누락 수정
'
accept 'feat: scope 없는 header 허용
'
accept 'feat(auth)!: 소셜 로그인 추가

BREAKING CHANGE: 기존 토큰 형식을 더 이상 받지 않는다
'

# 형식·type·scope.
reject '답변 렌더링 수정
' '형식이 아니다'
reject 'chore(chat) 콜론 누락
' '형식이 아니다'
reject 'feature(chat): 알 수 없는 type
' '형식이 아니다'
reject 'fix(billing): 선언하지 않은 scope
' '선언하지 않은 scope 다: billing'

# subject 길이는 글자 수로 센다. 한글을 바이트로 세면 정상 메시지가 3배로 계산된다.
accept 'docs(chat): 마흔아홉 글자가 넘지 않는 한국어 제목을 여기에 적어 확인
'
reject "docs(chat): $(printf '가%.0s' $(seq 1 51))
" '자다. 50자 이내로'

# 종결과 마침표.
reject 'fix(chat): 렌더링 누락을 수정한다
' '명사형'
reject 'fix(chat): 렌더링이 누락되던 것
' '명사형'
reject 'fix(chat): 렌더링 누락 수정.
' '마침표'

# 금지 trailer 와 헤더 다음 빈 줄.
reject 'fix(chat): 렌더링 누락 수정

Co-Authored-By: Someone <someone@example.test>
' 'Co-Authored-By 는 넣지 않는다'
reject 'fix(chat): 렌더링 누락 수정
붙어 있는 body 첫 줄
' '빈 줄이 필요하다'

# git 이 문안을 정하거나 rebase 가 흡수하는 메시지는 대상이 아니다.
accept 'Merge branch develop into main
'
accept 'fixup! fix(chat): 렌더링 누락 수정
'

# 나열은 막지 않고 알린다.
accept 'fix(chat): 렌더링·스크롤 누락 수정
'
grep -Fq '커밋을 쪼갤 신호' "$temporary/err"

# 종결 어미는 프로젝트가 고른 언어를 따라간다.
python3 - "$project/.engsys/project.yaml" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read().replace("subject-ending: 'noun'", "subject-ending: 'imperative'")
open(path, "w").write(text)
PY
accept 'fix(chat): drop the stale render guard
'
# imperative 는 기계가 판정하지 않는다. 접미사 규칙은 정상 subject 를 막는다('shared').
accept 'fix(chat): rename the guard to shared
'
reject 'fix(chat): drop the stale render guard.
' 'imperative'

# gate 는 launcher 가 없거나 이 subcommand 를 모르는 engsys 를 만나면 commit 을 막지 않는다.
hook="$temporary/commit-msg"
cp "$system_root/templates/project/.githooks/commit-msg" "$hook"
mkdir -p "$temporary/bin"
for tool in git printf; do
  tool_path=$(command -v "$tool" 2>/dev/null) || continue
  ln -sf "$tool_path" "$temporary/bin/$tool"
done
printf 'fix(chat): 렌더링 누락 수정\n' >"$message"
( cd "$project" && PATH="$temporary/bin" /bin/sh "$hook" "$message" ) >"$temporary/out" 2>"$temporary/err"
grep -Fq 'engsys is not on PATH' "$temporary/err"

printf '#!/bin/sh\nexit 1\n' >"$temporary/bin/engsys"
chmod +x "$temporary/bin/engsys"
( cd "$project" && PATH="$temporary/bin" /bin/sh "$hook" "$message" ) >"$temporary/out" 2>"$temporary/err"
grep -Fq 'no vcs check-message' "$temporary/err"

printf 'ok commit messages follow the system contract and the project declaration\n'
