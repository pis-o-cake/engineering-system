#!/bin/sh
# Claude Code PostToolUse hook. 방금 쓴 문서 하나의 구조만 검사하고 결과를 Claude에게 돌려준다.
# 구조는 판단이 필요 없으므로 즉시 알린다. 근거의 충분성은 편집 검토가 판정한다.

set -eu

. "$(dirname "$0")/hook-target.sh"
read_hook_target

case "$file_path" in *.md|*.html) ;; *) exit 0 ;; esac
[ -n "$project_dir" ] || exit 0
contract="$project_dir/.engsys/project.yaml"
[ -f "$contract" ] || exit 0
grep -q '^  authoring:' "$contract" || exit 0
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0

if findings=$(sh "$CLAUDE_PLUGIN_ROOT/bin/engsys" docs check \
    --project "$project_dir" --path "$file_path" 2>&1); then
  exit 0
fi

printf '%s\n' "$findings" >&2
printf '%s\n' 'This is the declared document type contract, not a style preference. Fix the document before continuing.' >&2
exit 2
