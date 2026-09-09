#!/bin/sh

# 문서 하나를 쓴 직후 그 문서만 검사해 Claude 에게 돌려주고, 세션 시작에 남은 상태를 알린다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0
project="$temporary/project"
mkdir -p "$project/docs/runbooks"
git -C "$project" init -q
git -C "$project" config user.name 'Feedback Fixture'
git -C "$project" config user.email 'fixture@example.test'
"$system_root/bin/engsys" init --project "$project" --verify true >/dev/null
cat >>"$project/.engsys/project.yaml" <<'EOF'
  authoring:
    assign:
      - path: 'docs/runbooks'
        type: 'runbook'
EOF

runbook="$project/docs/runbooks/deploy.md"
write_runbook() {
  cat >"$runbook" <<EOF
---
type: runbook
status: active
last-reviewed: 2026-09-08
---

# 배포 절차

운영 배포와 rollback 에 적용한다.
$1
EOF
}
complete_body='
## 적용 상황

운영 환경의 정기 배포에 쓴다.

## 실행 전 확인

배포 tag 와 DB 백업 시각을 확인한다.

## 절차

```sh
make deploy
```

## 성공 확인

/healthz 가 200 을 반환한다.

## 실패와 복구

직전 tag 로 rollback 한다.
'

docs() { "$system_root/bin/engsys" docs check --project "$project" "$@"; }

# --path 는 그 문서 하나만 본다.
write_runbook "$complete_body"
docs --path docs/runbooks/deploy.md >"$temporary/result"
grep -Fq '1 assigned documents, 0 findings' "$temporary/result"

# 배정 밖 경로와 없는 파일은 오류가 아니다. 편집 hook 은 모든 쓰기에서 돈다.
printf 'print("x")\n' >"$project/app.py"
docs --path app.py >/dev/null
docs --path docs/runbooks/absent.md >/dev/null

# 필수 절이 빠지면 그 문서만 실패한다.
write_runbook '
## 적용 상황

정기 배포에 쓴다.
'
if docs --path docs/runbooks/deploy.md >"$temporary/result" 2>&1; then
  printf 'Unexpected success for an incomplete runbook\n' >&2
  exit 1
fi
grep -Fq 'missing required section (precheck)' "$temporary/result"
grep -Fq 'docs/runbooks/deploy.md' "$temporary/result"

# PostToolUse hook 은 결과를 Claude 에게 돌려준다. 코드 파일에서는 아무 일도 하지 않는다.
hook() {
  printf '{"tool_name":"Write","cwd":"%s","tool_input":{"file_path":"%s"}}' "$project" "$1" \
    | CLAUDE_PLUGIN_ROOT="$system_root" CLAUDE_PROJECT_DIR="$project" \
      sh "$system_root/packages/docs-gov/claude-code/hooks/check-document-structure.sh" \
      >"$temporary/out" 2>"$temporary/err"
}
# exit 2 여야 stderr 가 Claude 에게 전달된다. 다른 코드는 조용히 무시된다.
status=0
hook "$project/docs/runbooks/deploy.md" || status=$?
if [ "$status" != 2 ]; then
  printf 'PostToolUse hook must exit 2 for an incomplete document, got %s\n' "$status" >&2
  cat "$temporary/err" >&2
  exit 1
fi
grep -Fq 'missing required section (precheck)' "$temporary/err"
grep -Fq 'not a style preference' "$temporary/err"

write_runbook "$complete_body"
hook "$project/docs/runbooks/deploy.md"
[ ! -s "$temporary/err" ]
hook "$project/app.py"
[ ! -s "$temporary/err" ]

# 배정 선언이 없는 프로젝트에서는 hook 이 조용히 끝난다.
bare="$temporary/bare"
mkdir -p "$bare/docs"
git -C "$bare" init -q
"$system_root/bin/engsys" init --project "$bare" --verify true >/dev/null
printf '# 문서\n' >"$bare/docs/note.md"
printf '{"tool_name":"Write","cwd":"%s","tool_input":{"file_path":"%s"}}' "$bare" "$bare/docs/note.md" \
  | CLAUDE_PLUGIN_ROOT="$system_root" CLAUDE_PROJECT_DIR="$bare" \
    sh "$system_root/packages/docs-gov/claude-code/hooks/check-document-structure.sh" \
    >"$temporary/out" 2>"$temporary/err"
[ ! -s "$temporary/out" ] && [ ! -s "$temporary/err" ]

# SessionStart 는 검토 backlog 만 센다. launcher 없이도 돌고, 구조는 다시 세지 않는다.
session() {
  printf '{"cwd":"%s"}' "$1" \
    | CLAUDE_PROJECT_DIR="$1" \
      sh "$system_root/packages/docs-gov/claude-code/hooks/session-status.sh" >"$temporary/out" 2>&1
}

# review.scopes 선언이 없으면 아무것도 말하지 않는다.
write_runbook '
## 적용 상황

정기 배포에 쓴다.
'
session "$project"
[ ! -s "$temporary/out" ]

cat >>"$project/.engsys/project.yaml" <<'EOF'
  review:
    scopes:
      - 'docs'
EOF
session "$project"
grep -Fq '"hookEventName": "SessionStart"' "$temporary/out"
grep -Fq '검토 기록이 없는 문서 1편' "$temporary/out"
python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$temporary/out"

# 구조 findings 는 세지 않는다. 그건 작성 시점과 push gate 의 일이다.
if grep -Fq '구조' "$temporary/out"; then
  printf 'SessionStart must not re-count structure findings\n' >&2
  exit 1
fi

# 검토 기록이 있는 문서는 세지 않는다.
mkdir -p "$project/.engsys/reviews/docs/runbooks"
printf 'engsys-document-review: 1\n' >"$project/.engsys/reviews/docs/runbooks/deploy.md.review"
session "$project"
[ ! -s "$temporary/out" ]

# 생성 문서는 검토 대상이 아니다.
printf '# Generated\n' >"$project/docs/generated.md"
printf 'docs/generated.md\n' >"$project/.engsys/generated-paths.txt"
session "$project"
[ ! -s "$temporary/out" ]
rm "$project/docs/generated.md"
: >"$project/.engsys/generated-paths.txt"

# 계약이 없는 디렉토리에서는 아무것도 출력하지 않는다.
mkdir -p "$temporary/plain"
git -C "$temporary/plain" init -q
session "$temporary/plain"
[ ! -s "$temporary/out" ]

printf 'ok document structure feedback reaches the session that wrote it\n'
