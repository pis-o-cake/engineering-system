#!/bin/sh

# Check a branch name against the patterns the project declared. The model's naming field is a
# default the project can replace; a project that declares no patterns is not checked.
set -eu

fail_usage() { printf 'engsys vcs: %s\n' "$*" >&2; exit 2; }
usage() {
  cat <<'EOF'
Usage:
  engsys vcs check-branch [--project <directory>] [--branch <name>]

Patterns come from vcs.branch.naming in the project contract. Protected branches and a detached
HEAD are never rejected. A project that declares no patterns is not checked.
EOF
}

project=$(pwd)
branch=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project) [ "$#" -ge 2 ] || fail_usage '--project requires a value'; project=$2; shift 2 ;;
    --branch) [ "$#" -ge 2 ] || fail_usage '--branch requires a value'; branch=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail_usage "unknown option: $1" ;;
  esac
done

[ -d "$project" ] || fail_usage "project does not exist: $project"
project=$(CDPATH= cd -- "$project" && pwd -P)
declaration="$project/.engsys/project.yaml"
[ -f "$declaration" ] || exit 0
grep -q '^vcs:' "$declaration" || exit 0

[ -n "$branch" ] || branch=$(git -C "$project" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
# detached HEAD 는 이름이 없다. rebase 중이거나 tag 를 본 상태라 판정 대상이 아니다.
[ -n "$branch" ] && [ "$branch" != HEAD ] || exit 0

work=$(mktemp -d)
trap 'rm -rf "$work"' 0
awk '
  function unq(text) {
    gsub(/^[ \t]+|[ \t]+$/, "", text)
    if (text ~ /^\047.*\047$/) { text = substr(text, 2, length(text) - 2); gsub(/\047\047/, "\047", text) }
    return text
  }
  /^vcs:$/ { in_vcs = 1; next }
  /^[A-Za-z]/ { in_vcs = 0 }
  in_vcs && /^  [a-z-]+:$/ { group = $0; sub(/^  /, "", group); sub(/:$/, "", group); field = ""; next }
  in_vcs && /^    [a-z-]+:/ {
    line = $0; sub(/^    /, "", line); sub(/:.*$/, "", line); field = line; next
  }
  in_vcs && group == "branch" && /^      - / {
    value = $0; sub(/^      - /, "", value); print field "\t" unq(value)
  }
' "$declaration" >"$work/branch"

tab=$(printf '\t')
awk -F"$tab" '$1 == "naming" { print $2 }' "$work/branch" >"$work/naming"
[ -s "$work/naming" ] || exit 0

# protected branch 는 이름 규칙의 대상이 아니다. 새로 만드는 branch 가 아니라 이미 있는 것이다.
awk -F"$tab" '$1 == "protected" { print $2 }' "$work/branch" >"$work/protected"
while IFS= read -r protected; do
  [ -n "$protected" ] || continue
  [ "$branch" != "$protected" ] || exit 0
done <"$work/protected"

while IFS= read -r pattern; do
  [ -n "$pattern" ] || continue
  case "$branch" in $pattern) exit 0 ;; esac
done <"$work/naming"

printf '\nbranch: 선언한 이름 규칙에 맞지 않는다: %s\n\n' "$branch" >&2
printf '  허용: %s\n' "$(tr '\n' ' ' <"$work/naming")" >&2
printf '  선언: .engsys/project.yaml 의 vcs.branch.naming\n\n' >&2
exit 1
