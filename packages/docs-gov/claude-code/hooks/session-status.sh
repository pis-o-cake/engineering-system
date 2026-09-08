#!/bin/sh
# Claude Code SessionStart hook. 이 프로젝트가 지금 계약을 만족하는지 한 줄로 알려 준다.
# 검사를 대신하지 않으며, 무엇도 막지 않는다.

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
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0
launcher="$CLAUDE_PLUGIN_ROOT/bin/engsys"
[ -f "$launcher" ] || exit 0

count_from() { printf '%s\n' "$1" | sed -n "s/.*documents, \\([0-9][0-9]*\\) $2.*/\\1/p" | sed -n '1p'; }

summary=
if grep -q '^  authoring:' "$contract"; then
  output=$(sh "$launcher" docs check --project "$project_dir" 2>&1 || true)
  findings=$(count_from "$output" findings)
  if [ -n "$findings" ] && [ "$findings" != 0 ]; then
    summary="구조 검사 findings ${findings}건"
  fi
fi
if grep -q '^  review:' "$contract"; then
  output=$(sh "$launcher" review check --project "$project_dir" 2>&1 || true)
  pending=$(count_from "$output" pending)
  if [ -n "$pending" ] && [ "$pending" != 0 ]; then
    summary="${summary}${summary:+, }미검토 문서 ${pending}편"
  fi
fi

[ -n "$summary" ] || exit 0
summary=$(printf '%s' "$summary" | tr -d '"\\')
cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Engineering System: $summary. 이 프로젝트의 문서를 고칠 때 engsys docs check 로 구조를 확인하고 /engsys:review-document 로 최종본을 검토한다."
  }
}
JSON
