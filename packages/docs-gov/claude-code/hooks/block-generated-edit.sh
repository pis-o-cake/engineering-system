#!/bin/sh
# Claude Code PreToolUse hook. Bootstrap이 만든 목록에 있는 generated output은 Edit·Write로
# 고치지 못하게 하고, generator를 실행하라고 돌려보낸다.

set -eu

. "$(dirname "$0")/hook-target.sh"
read_hook_target

generated_paths="$project_dir/.engsys/generated-paths.txt"

[ -n "$file_path" ] && [ -f "$generated_paths" ] || exit 0

if grep -Fqx -- "$file_path" "$generated_paths"; then
  cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Generated documentation is owned by its declared generator. Run the generator or its verify command instead of editing this file."
  }
}
JSON
fi
