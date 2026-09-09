#!/bin/sh

# Resolve the project's branch settings and answer questions about them. The model defines roles
# and direction; the project names the branches. Nothing here hardcodes a branch name.
set -eu

fail_usage() { printf 'engsys vcs: %s\n' "$*" >&2; exit 2; }
usage() {
  cat <<'EOF'
Usage:
  engsys vcs base-branch [--project <directory>] [--branch <name>]
  engsys vcs check-settings [--project <directory>]
  engsys vcs settings [--project <directory>]

base-branch prints the branch a new branch is cut from. check-settings validates the declaration
against the model. settings prints the resolved values. A project that declares no vcs block is
not checked and prints nothing.
EOF
}

action=${1:-help}
[ "$#" -eq 0 ] || shift
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
case "$action" in base-branch|check-settings|settings) ;; help) usage; exit 0 ;; *) fail_usage "unknown action: $action" ;; esac

system_root=${ENGSYS_SYSTEM_ROOT:?ENGSYS_SYSTEM_ROOT is not set}
contract="$system_root/packages/vcs-gov/commit-contract.yaml"
[ -f "$contract" ] || fail_usage "commit contract is missing: $contract"
[ -d "$project" ] || fail_usage "project does not exist: $project"
project=$(CDPATH= cd -- "$project" && pwd -P)
declaration="$project/.engsys/project.yaml"
[ -f "$declaration" ] || exit 0
grep -q '^vcs:' "$declaration" || exit 0

work=$(mktemp -d)
trap 'rm -rf "$work"' 0
tab=$(printf '\t')
unq='
  function unq(text) {
    gsub(/^[ \t]+|[ \t]+$/, "", text)
    if (text ~ /^\047.*\047$/) { text = substr(text, 2, length(text) - 2); gsub(/\047\047/, "\047", text) }
    return text
  }'

# 프로젝트 선언. roles 는 선언 순서가 승격 순서다.
awk "$unq"'
  /^vcs:$/ { in_vcs = 1; next }
  /^[A-Za-z]/ { in_vcs = 0 }
  in_vcs && /^  [a-z-]+:$/ { group = $0; sub(/^  /, "", group); sub(/:$/, "", group); field = ""; next }
  in_vcs && /^    [a-z-]+:/ {
    line = $0; sub(/^    /, "", line); position = index(line, ":")
    field = substr(line, 1, position - 1); value = unq(substr(line, position + 1))
    if (group == "branch" && field == "model" && value != "") print "model\t" value
    if (group == "merge-request" && field == "target" && value != "") print "target\t" value
    next
  }
  in_vcs && group == "branch" && field == "roles" && /^      - role:/ {
    line = $0; sub(/^      - role:/, "", line); pending = unq(line); next
  }
  in_vcs && group == "branch" && field == "roles" && /^        branch:/ {
    line = $0; sub(/^        branch:/, "", line)
    print "role\t" pending "\t" unq(line); pending = ""; next
  }
  in_vcs && group == "branch" && field == "prefixes" && /^      [a-z-]+:/ {
    line = $0; sub(/^      /, "", line); position = index(line, ":")
    print "prefix\t" substr(line, 1, position - 1) "\t" unq(substr(line, position + 1)); next
  }
  in_vcs && group == "branch" && /^      - / {
    value = $0; sub(/^      - /, "", value)
    if (field == "protected") print "protected\t" unq(value)
    if (field == "naming") print "naming\t" unq(value)
    next
  }
' "$declaration" >"$work/declared"

# 계약 기본값.
awk "$unq"'
  /^branch-defaults:$/ { in_defaults = 1; next }
  /^[a-z-]/ { in_defaults = 0 }
  in_defaults && /^  [a-z-]+:$/ { group = $0; sub(/^  /, "", group); sub(/:$/, "", group); next }
  in_defaults && group == "roles" && /^    - role:/ {
    line = $0; sub(/^    - role:/, "", line); pending = unq(line); next
  }
  in_defaults && group == "roles" && /^      branch:/ {
    line = $0; sub(/^      branch:/, "", line); print "role\t" pending "\t" unq(line); next
  }
  in_defaults && group == "prefixes" && /^    [a-z-]+:/ {
    line = $0; sub(/^    /, "", line); position = index(line, ":")
    print "prefix\t" substr(line, 1, position - 1) "\t" unq(substr(line, position + 1)); next
  }
' "$contract" >"$work/defaults"

model=$(awk -F"$tab" '$1 == "model" { print $2; exit }' "$work/declared")
target=$(awk -F"$tab" '$1 == "target" { print $2; exit }' "$work/declared")
awk "$unq"'
  /^branch-models:$/ { in_models = 1; next }
  /^[a-z-]/ { in_models = 0 }
  in_models && /^  - name:/ { line = $0; sub(/^  - name:[ \t]*/, "", line); name = unq(line); next }
  in_models && /^    required-roles:/ {
    line = $0; sub(/^    required-roles:[ \t]*\[/, "", line); sub(/\].*$/, "", line)
    gsub(/[\047 ]/, "", line)
    split(line, parts, ",")
    for (index_part = 1; index_part <= length(parts); index_part++)
      if (parts[index_part] != "") print name "\trequired\t" parts[index_part]
    next
  }
  in_models && /^    extra-roles:/ {
    line = $0; sub(/^    extra-roles:[ \t]*/, "", line); print name "\textra\t" unq(line); next
  }
' "$contract" >"$work/models"
awk -F"$tab" -v want="$model" '$1 == want && $2 == "required" { print $3 }' "$work/models" \
  >"$work/required"

awk -F"$tab" '$1 == "role" { print $2 "\t" $3 }' "$work/declared" >"$work/roles"
if [ ! -s "$work/roles" ]; then
  # 선언이 없으면 계약 기본값을 쓰되 model 이 요구하는 역할만 남긴다. 그러지 않으면
  # single-main 프로젝트가 쓰지 않는 역할 때문에 처음부터 실패한다.
  if [ -s "$work/required" ]; then
    while IFS= read -r wanted; do
      [ -n "$wanted" ] || continue
      awk -F"$tab" -v want="$wanted" '$1 == "role" && $2 == want { print $2 "\t" $3 }' \
        "$work/defaults"
    done <"$work/required" >"$work/roles"
  else
    awk -F"$tab" '$1 == "role" { print $2 "\t" $3 }' "$work/defaults" >"$work/roles"
  fi
fi
awk -F"$tab" '$1 == "prefix" { print $2 "\t" $3 }' "$work/declared" >"$work/prefixes"
[ -s "$work/prefixes" ] || awk -F"$tab" '$1 == "prefix" { print $2 "\t" $3 }' "$work/defaults" >"$work/prefixes"
awk -F"$tab" '$1 == "protected" { print $2 }' "$work/declared" >"$work/protected"

role_branch() { awk -F"$tab" -v want="$1" '$1 == want { print $2; exit }' "$work/roles"; }
first_branch() { sed -n '1p' "$work/roles" | cut -f2; }
last_branch() { sed -n '$p' "$work/roles" | cut -f2; }
prefix_of() { awk -F"$tab" -v want="$1" '$1 == want { print $2; exit }' "$work/prefixes"; }

if [ "$action" = settings ]; then
  printf 'model\t%s\n' "${model:-<미선언>}"
  printf 'target\t%s\n' "${target:-$(first_branch)}"
  sed 's/^/role\t/' "$work/roles"
  sed 's/^/prefix\t/' "$work/prefixes"
  exit 0
fi

if [ "$action" = base-branch ]; then
  [ -n "$branch" ] || branch=$(git -C "$project" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  hotfix=$(prefix_of hotfix)
  # single-main 은 역할이 하나라 첫 branch 와 마지막 branch 가 같다. 분기가 필요 없다.
  if [ -n "$hotfix" ] && [ -n "$branch" ]; then
    case "$branch" in "$hotfix"*) last_branch; exit 0 ;; esac
  fi
  first_branch
  exit 0
fi

# check-settings
problems=0
report() { printf 'FAIL vcs.branch: %s\n' "$1" >&2; problems=$((problems + 1)); }

if [ -z "$model" ]; then
  report 'model 을 선언하지 않았다'
elif ! grep -q "^$model	" "$work/models"; then
  report "알 수 없는 model 이다: $model (선언된 것: $(cut -f1 "$work/models" | sort -u | tr '\n' ' '))"
else
  while IFS= read -r required; do
    [ -n "$required" ] || continue
    [ -n "$(role_branch "$required")" ] \
      || report "model $model 은 $required 역할을 요구한다. vcs.branch.roles 에 선언한다"
  done <"$work/required"
  extra=$(awk -F"$tab" -v want="$model" '$1 == want && $2 == "extra" { print $3; exit }' "$work/models")
  if [ "$extra" = rejected ]; then
    while IFS="$tab" read -r role_name role_value; do
      [ -n "$role_name" ] || continue
      grep -Fxq -- "$role_name" "$work/required" \
        || report "model $model 은 $role_name 역할을 쓰지 않는다. roles 에서 뺀다"
    done <"$work/roles"
  fi
fi

# 같은 branch 이름을 두 역할에 쓰면 승격 방향이 성립하지 않는다.
duplicate=$(cut -f2 "$work/roles" | sort | uniq -d | sed -n '1p')
[ -z "$duplicate" ] || report "두 역할이 같은 branch 를 가리킨다: $duplicate"

# 선언한 protected 는 역할 branch 를 모두 포함해야 한다. 선언이 없으면 검사하지 않는다.
if [ -s "$work/protected" ]; then
  while IFS="$tab" read -r role_name role_value; do
    [ -n "$role_value" ] || continue
    grep -Fxq -- "$role_value" "$work/protected" \
      || report "$role_name 역할 branch $role_value 가 protected 에 없다"
  done <"$work/roles"
fi

# MR 대상은 역할 branch 중 하나여야 한다. 아니면 승격 경로 밖으로 병합된다.
if [ -n "$target" ] && ! cut -f2 "$work/roles" | grep -Fxq -- "$target"; then
  report "merge-request.target $target 는 역할 branch 가 아니다: $(cut -f2 "$work/roles" | tr '\n' ' ')"
fi

while IFS="$tab" read -r prefix_kind prefix_value; do
  [ -n "$prefix_kind" ] || continue
  case "$prefix_value" in
    */) ;;
    *) report "$prefix_kind 접두사는 / 로 끝나야 한다: $prefix_value" ;;
  esac
  cut -f2 "$work/roles" | grep -Fxq -- "${prefix_value%/}" \
    && report "$prefix_kind 접두사가 역할 branch 이름과 같다: $prefix_value"
done <"$work/prefixes"

[ "$problems" -eq 0 ] || exit 1
printf 'Branch settings: model %s, roles %s\n' "$model" "$(cut -f2 "$work/roles" | tr '\n' ' ')"
