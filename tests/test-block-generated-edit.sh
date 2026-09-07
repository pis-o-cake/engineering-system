#!/bin/sh

set -eu

test_dir=$(mktemp -d)
cleanup() {
  cleanup_status=$?
  rm -rf "$test_dir"
  trap - 0 1 2 15
  exit "$cleanup_status"
}
trap cleanup 0 1 2 15
git -C "$test_dir" init -q
mkdir -p "$test_dir/.engsys"
printf '%s\n' 'docs/generated.md' >"$test_dir/.engsys/generated-paths.txt"

denied=$(printf '%s' '{"tool_input":{"file_path":"docs/generated.md"}}' \
  | CLAUDE_PROJECT_DIR="$test_dir" sh hooks/block-generated-edit.sh)
denied_absolute=$(printf '%s' "{\"tool_input\":{\"file_path\":\"$test_dir/docs/generated.md\"}}" \
  | CLAUDE_PROJECT_DIR="$test_dir" sh hooks/block-generated-edit.sh)
denied_worktree=$(printf '%s' "{\"cwd\":\"$test_dir\",\"tool_input\":{\"file_path\":\"$test_dir/docs/generated.md\"}}" \
  | CLAUDE_PROJECT_DIR='/not-the-current-worktree' sh hooks/block-generated-edit.sh)
allowed=$(printf '%s' '{"tool_input":{"file_path":"docs/guide.md"}}' \
  | CLAUDE_PROJECT_DIR="$test_dir" sh hooks/block-generated-edit.sh)

printf '%s' "$denied" | grep -Fq 'permissionDecision' || exit 1
printf '%s' "$denied_absolute" | grep -Fq 'permissionDecision' || exit 1
printf '%s' "$denied_worktree" | grep -Fq 'permissionDecision' || exit 1
[ -z "$allowed" ]
