#!/bin/sh

# Resolve the project's unresolved-item tracker declaration. The standard owns when to register,
# what an item must carry and what closes it; the project names the tracker and the permissions.
# Nothing here hardcodes a tracker, a label or a permission.
set -eu

fail_usage() { printf 'engsys vcs: %s\n' "$*" >&2; exit 2; }
usage() {
  cat <<'EOF'
Usage:
  engsys vcs tracker [--project <directory>]
  engsys vcs check-tracker [--project <directory>]

tracker prints the resolved declaration: provider, project, default assignee, label mapping and
the agent permissions. check-tracker validates the declaration against the contract. A project
that declares no vcs.tracker is not checked and prints nothing.
EOF
}

action=${1:-tracker}
[ "$#" -eq 0 ] || shift
project=$(pwd)
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project) [ "$#" -ge 2 ] || fail_usage '--project requires a value'; project=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail_usage "unknown option: $1" ;;
  esac
done
case "$action" in
  tracker|check-tracker) ;;
  help) usage; exit 0 ;;
  *) fail_usage "unknown action: $action" ;;
esac

system_root=${ENGSYS_SYSTEM_ROOT:?ENGSYS_SYSTEM_ROOT is not set}
contract="$system_root/packages/vcs-gov/tracker-contract.yaml"
[ -f "$contract" ] || fail_usage "tracker contract is missing: $contract"
[ -d "$project" ] || fail_usage "project does not exist: $project"
project=$(CDPATH= cd -- "$project" && pwd -P)
declaration="$project/.engsys/project.yaml"
[ -f "$declaration" ] || exit 0
grep -q '^vcs:' "$declaration" || exit 0

work=$(mktemp -d)
trap 'rm -rf "$work"' 0
trap 'exit 129' 1
trap 'exit 130' 2
trap 'exit 143' 15
tab=$(printf '\t')

unq='
  function unq(text) {
    gsub(/^[ \t]+|[ \t]+$/, "", text)
    if (text ~ /^\047.*\047$/) { text = substr(text, 2, length(text) - 2); gsub(/\047\047/, "\047", text) }
    return text
  }'

# vcs.tracker 만 "group<TAB>key<TAB>value" 로 편다.
awk "$unq"'
  /^vcs:$/ { in_vcs = 1; next }
  /^[A-Za-z]/ { in_vcs = 0 }
  !in_vcs { next }
  /^  [a-z-]+:/ { in_tracker = ($0 == "  tracker:"); group = "tracker"; next }
  !in_tracker { next }
  /^    [a-z-]+:[[:space:]]*$/ {
    line = $0; sub(/^    /, "", line); sub(/:[[:space:]]*$/, "", line); group = line; next
  }
  /^    [a-z-]+:/ {
    line = $0; sub(/^    /, "", line); position = index(line, ":")
    group = "tracker"
    print group "\t" substr(line, 1, position - 1) "\t" unq(substr(line, position + 1)); next
  }
  /^      [a-z-]+:/ {
    line = $0; sub(/^      /, "", line); position = index(line, ":")
    print group "\t" substr(line, 1, position - 1) "\t" unq(substr(line, position + 1)); next
  }
' "$declaration" >"$work/declared"

[ -s "$work/declared" ] || exit 0

declared() { awk -F"$tab" -v g="$1" -v k="$2" '$1 == g && $2 == k { print $3; exit }' "$work/declared"; }

# 계약의 기본 권한과 항상 사람이 판단할 것을 읽는다.
awk "$unq"'
  /^agent-permissions:$/ { in_block = 1; next }
  /^[a-z-]/ { in_block = 0 }
  !in_block { next }
  /^  defaults:$/ { section = "default"; next }
  /^  always-human:$/ { section = "human"; next }
  /^  [a-z-]+:/ { section = ""; next }
  section == "default" && /^    [a-z-]+:/ {
    line = $0; sub(/^    /, "", line); position = index(line, ":")
    print "default\t" substr(line, 1, position - 1) "\t" unq(substr(line, position + 1)); next
  }
  section == "human" && /^    - / { line = $0; sub(/^    - /, "", line); print "human\t" unq(line) "\t"; next }
' "$contract" >"$work/contract"

contract_default() { awk -F"$tab" -v k="$1" '$1 == "default" && $2 == k { print $3; exit }' "$work/contract"; }
always_human() { awk -F"$tab" '$1 == "human" { print $2 }' "$work/contract"; }

provider=$(declared tracker provider)
target=$(declared tracker project)

if [ "$action" = check-tracker ]; then
  findings=0
  report() { findings=$((findings + 1)); printf 'tracker: %s\n' "$1" >&2; }
  [ -n "$provider" ] || report 'vcs.tracker.provider 를 선언하지 않았다'
  [ -n "$target" ] || report 'vcs.tracker.project 를 선언하지 않았다'
  case "$provider" in ''|github|gitlab) ;; *) report "지원하지 않는 provider 다: $provider" ;; esac
  for permission in $(always_human); do
    value=$(declared agent "$permission")
    [ "$value" != allowed ] \
      || report "$permission 은 사람이 판단한다. allowed 로 선언할 수 없다"
  done
  for permission in search create comment close accept-risk commit-deadline; do
    value=$(declared agent "$permission")
    case "$value" in ''|allowed|ask) ;; *) report "agent.$permission 값이 allowed·ask 가 아니다: $value" ;; esac
  done
  if [ "$findings" -ne 0 ]; then
    printf '\n  계약: packages/vcs-gov/tracker-contract.yaml\n\n' >&2
    exit 1
  fi
  printf 'Tracker settings: %s %s\n' "$provider" "$target"
  exit 0
fi

printf 'provider\t%s\n' "$provider"
printf 'project\t%s\n' "$target"
assignee=$(declared tracker default-assignee)
printf 'default-assignee\t%s\n' "${assignee:-미정}"
for kind in defect task decision blocked risk; do
  value=$(declared labels "$kind")
  [ -z "$value" ] || printf 'label\t%s\t%s\n' "$kind" "$value"
done
for permission in search create comment close accept-risk commit-deadline; do
  value=$(declared agent "$permission")
  [ -n "$value" ] || value=$(contract_default "$permission")
  printf 'agent\t%s\t%s\n' "$permission" "${value:-ask}"
done
