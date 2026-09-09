#!/bin/sh
# Claude Code SessionStart hook. 이 세션이 만들지 않은 검토 backlog 만 한 줄로 알려 준다.
# 구조는 작성 시점의 PostToolUse 와 push gate 가 본다. 여기서 다시 세지 않는다.
# 무엇도 막지 않으며, 실패해도 세션을 시작시킨다.

set -eu

hook_input=$(cat 2>/dev/null || true)
cwd=$(printf '%s' "$hook_input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
project_dir=${CLAUDE_PROJECT_DIR:-$cwd}
[ -n "$project_dir" ] || exit 0
if git -C "$project_dir" rev-parse --show-toplevel >/dev/null 2>&1; then
  project_dir=$(git -C "$project_dir" rev-parse --show-toplevel)
fi
contract="$project_dir/.engsys/project.yaml"
[ -f "$contract" ] || exit 0

scopes=$(awk '
  /^documentation:$/ { in_documentation = 1; next }
  /^[A-Za-z]/ { in_documentation = 0 }
  in_documentation && /^  review:$/ { in_review = 1; next }
  in_documentation && /^  [a-z-]+:/ { in_review = 0 }
  in_review && /^    scopes:$/ { in_scopes = 1; next }
  in_review && /^    [a-z-]+:/ { in_scopes = 0 }
  in_scopes && /^      - / {
    value = $0; sub(/^      - /, "", value)
    gsub(/^[ \t]+|[ \t]+$/, "", value)
    if (value ~ /^\047.*\047$/) { value = substr(value, 2, length(value) - 2); gsub(/\047\047/, "\047", value) }
    print value
  }
' "$contract")
[ -n "$scopes" ] || exit 0

cd "$project_dir" || exit 0
# 검토 기록 파일의 존재만 본다. 본문 해시 대조는 engsys review check 의 일이고, 세션마다
# 전 문서를 다시 해시하면 이 hook 이 세션 시작을 지연시킨다.
# bash 3.2 는 명령 치환 안의 case 를 잘못 읽으므로 결과를 파일로 받는다.
missing=$(mktemp) || exit 0
trap 'rm -f "$missing"' 0
# scope 마다 git 을 띄우면 선언이 늘어난 프로젝트에서 그만큼 느려진다. 한 번에 넘긴다.
printf '%s\n' "$scopes" >"$missing"
set --
while IFS= read -r scope; do
  [ -n "$scope" ] || continue
  case "$scope" in /*|..|../*|*/../*|*/..) continue ;; esac
  set -- "$@" ":(literal)${scope%/}"
done <"$missing"
[ "$#" -gt 0 ] || exit 0
git -c core.quotePath=false ls-files --cached --others --exclude-standard -- "$@" 2>/dev/null \
  | LC_ALL=C sort -u | while IFS= read -r path; do
  case "$path" in .engsys/*) continue ;; *.md|*.html) ;; *) continue ;; esac
  if [ -f .engsys/generated-paths.txt ] && grep -Fxq -- "$path" .engsys/generated-paths.txt; then
    continue
  fi
  [ -f ".engsys/reviews/$path.review" ] || printf '%s\n' "$path"
done >"$missing"
pending=$(wc -l <"$missing" | tr -d ' ')

[ -n "$pending" ] && [ "$pending" != 0 ] || exit 0
cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Engineering System: 편집 검토 기록이 없는 문서 ${pending}편이 있다. 그 문서를 고치거나 완료할 때 /engsys:review-document 로 한 편씩 검토하고 기록을 남긴다. 남은 검사는 engsys verify 가 본다."
  }
}
JSON
