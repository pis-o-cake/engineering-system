#!/bin/sh

set -eu

system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
hook="$system_root/packages/docs-gov/claude-code/hooks/block-generated-edit.sh"
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
  | CLAUDE_PROJECT_DIR="$test_dir" sh "$hook")
denied_absolute=$(printf '%s' "{\"tool_input\":{\"file_path\":\"$test_dir/docs/generated.md\"}}" \
  | CLAUDE_PROJECT_DIR="$test_dir" sh "$hook")
denied_worktree=$(printf '%s' "{\"cwd\":\"$test_dir\",\"tool_input\":{\"file_path\":\"$test_dir/docs/generated.md\"}}" \
  | CLAUDE_PROJECT_DIR='/not-the-current-worktree' sh "$hook")
allowed=$(printf '%s' '{"tool_input":{"file_path":"docs/guide.md"}}' \
  | CLAUDE_PROJECT_DIR="$test_dir" sh "$hook")

# 실패한 경우를 이름으로 알린다. 조용히 종료하면 어느 경로 형태가 깨졌는지 알 수 없다.
expect_denied() {
  printf '%s' "$2" | grep -Fq 'permissionDecision' && return 0
  printf 'generated edit was not denied: %s\n' "$1" >&2
  printf 'hook output: [%s]\n' "$2" >&2
  exit 1
}

expect_denied 'project-relative path' "$denied"
expect_denied 'absolute path' "$denied_absolute"
expect_denied 'worktree cwd overrides CLAUDE_PROJECT_DIR' "$denied_worktree"
[ -z "$allowed" ] || {
  printf 'an authored document must not be denied: [%s]\n' "$allowed" >&2
  exit 1
}
