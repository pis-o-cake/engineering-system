#!/bin/sh
# Claude Code PreToolUse hook. Bootstrap이 만든 목록에 있는 generated output은 Edit·Write로
# 고치지 못하게 하고, generator를 실행하라고 돌려보낸다.

set -eu

hook_input=$(cat)
file_path=$(printf '%s' "$hook_input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
cwd=$(printf '%s' "$hook_input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
project_dir=${CLAUDE_PROJECT_DIR:-}

# Claude가 worktree 또는 하위 디렉터리에서 작업하면 hook input의 cwd가 실제 checkout을
# 가리킨다. Git으로 root를 찾을 수 있을 때만 그것을 우선한다.
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --show-toplevel >/dev/null 2>&1; then
  project_dir=$(git -C "$cwd" rev-parse --show-toplevel)
fi

# Edit·Write는 absolute 또는 project-relative path를 받을 수 있다. 목록은 portable한
# project-relative path만 저장하므로 absolute path를 여기서 맞춘다.
case "$file_path" in
  "$project_dir"/*) file_path=${file_path#"$project_dir"/} ;;
esac

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
