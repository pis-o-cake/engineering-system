#!/bin/sh

# Create a document skeleton for a declared type: metadata, filename, and the required headings.
# The skeleton does not pass the structure check — the sections are empty until the author writes
# them. It removes the typing, not the writing.
set -eu

fail() { printf 'engsys docs new: %s\n' "$*" >&2; exit 2; }
usage() {
  cat <<'EOF'
Usage:
  engsys docs new --type <type> <slug> [--project <directory>] [--path <directory>] [--title <text>]

The destination comes from documentation.authoring.assign for that type unless --path is given.
The filename form comes from the type contract: numbered, dated, or slug.
EOF
}

project=$(pwd)
type_name=
slug=
destination=
title=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project) [ "$#" -ge 2 ] || fail '--project requires a value'; project=$2; shift 2 ;;
    --type) [ "$#" -ge 2 ] || fail '--type requires a value'; type_name=$2; shift 2 ;;
    --path) [ "$#" -ge 2 ] || fail '--path requires a value'; destination=$2; shift 2 ;;
    --title) [ "$#" -ge 2 ] || fail '--title requires a value'; title=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) fail "unknown option: $1" ;;
    *) [ -z "$slug" ] || fail 'one slug only'; slug=$1; shift ;;
  esac
done
[ -n "$type_name" ] || fail 'declare the document type with --type'
[ -n "$slug" ] || fail 'give a slug, for example cache-strategy'
case "$slug" in *[!a-z0-9-]*) fail "slug uses lowercase letters, digits and hyphens: $slug" ;; esac

system_root=${ENGSYS_SYSTEM_ROOT:?ENGSYS_SYSTEM_ROOT is not set}
contract="$system_root/packages/docs-gov/document-types.yaml"
[ -f "$contract" ] || fail "document type contract is missing: $contract"
[ -d "$project" ] || fail "project does not exist: $project"
project=$(CDPATH= cd -- "$project" && pwd -P)

work=$(mktemp -d)
trap 'rm -rf "$work"' 0
tab=$(printf '\t')

# 유형 하나의 선언만 뽑는다. sections 는 heading 순서를 유지한다.
awk -v want="$type_name" '
  function unq(text) {
    gsub(/^[ \t]+|[ \t]+$/, "", text)
    if (text ~ /^\047.*\047$/) { text = substr(text, 2, length(text) - 2); gsub(/\047\047/, "\047", text) }
    return text
  }
  function emit_list(field, text,   count, parts, index_part, value) {
    sub(/^\[/, "", text); sub(/\]$/, "", text)
    count = split(text, parts, ",")
    for (index_part = 1; index_part <= count; index_part++) {
      value = unq(parts[index_part])
      if (value != "") print field "\t" value
    }
  }
  /^types:$/ { in_types = 1; next }
  /^[a-z-]/ { in_types = 0 }
  in_types && /^  [a-z-]+:$/ {
    name = $0; sub(/^  /, "", name); sub(/:$/, "", name); selected = (name == want); next
  }
  selected && /^    [a-z-]+:/ {
    line = $0; sub(/^    /, "", line); position = index(line, ":")
    field = substr(line, 1, position - 1); value = unq(substr(line, position + 1))
    if (value ~ /^\[/) emit_list(field, value)
    else if (value != "") print field "\t" value
    next
  }
  selected && /^        heading:/ {
    line = $0; sub(/^        heading:/, "", line); print "heading\t" unq(line); next
  }
' "$contract" >"$work/type"
[ -s "$work/type" ] || fail "unknown document type: $type_name"

value_of() { awk -F"$tab" -v key="$1" '$1 == key { print $2; exit }' "$work/type"; }
values_of() { awk -F"$tab" -v key="$1" '$1 == key { print $2 }' "$work/type"; }

# 배정한 경로가 있으면 그것이 이 유형의 자리다. 없으면 --path 로 받는다.
if [ -z "$destination" ] && [ -f "$project/.engsys/project.yaml" ]; then
  destination=$(awk -v want="$type_name" '
    function unq(text) {
      gsub(/^[ \t]+|[ \t]+$/, "", text)
      if (text ~ /^\047.*\047$/) { text = substr(text, 2, length(text) - 2) }
      return text
    }
    /^documentation:$/ { in_documentation = 1; next }
    /^[A-Za-z]/ { in_documentation = 0 }
    in_documentation && /^  authoring:$/ { in_authoring = 1; next }
    in_documentation && /^  [a-z-]+:/ { in_authoring = 0 }
    in_authoring && /^      - path:/ { line = $0; sub(/^      - path:/, "", line); pending = unq(line); next }
    in_authoring && /^        type:/ {
      line = $0; sub(/^        type:/, "", line)
      if (unq(line) == want && pending !~ /[*?]/) { print pending; exit }
      pending = ""
    }
  ' "$project/.engsys/project.yaml")
fi
[ -n "$destination" ] \
  || fail "no path is assigned to $type_name; pass --path or add the assignment to the contract"
case "$destination" in /*|..|../*|*/../*|*/..) fail "path must be project-relative: $destination" ;; esac
mkdir -p "$project/$destination"

filename_form=$(value_of filename)
[ -n "$filename_form" ] || filename_form=slug
case "$filename_form" in
  numbered)
    next=$(ls "$project/$destination" 2>/dev/null \
      | sed -n 's/^\([0-9][0-9]*\)-.*/\1/p' | sort -n | tail -1)
    # 앞의 0 을 지운다. POSIX 산술은 0 으로 시작하는 값을 8진수로 읽어 0015 다음이 0014 가 된다.
    next=$(printf '%s' "${next:-0}" | sed 's/^0*//')
    [ -n "$next" ] || next=0
    next=$((next + 1))
    name=$(printf '%04d-%s.md' "$next" "$slug")
    ;;
  dated) name=$(date +%Y-%m-%d)-$slug.md ;;
  *) name=$slug.md ;;
esac
target="$project/$destination/$name"
[ ! -e "$target" ] || fail "already exists: $destination/$name"

[ -n "$title" ] || title=$(printf '%s' "$slug" | tr '-' ' ')
status=$(values_of statuses | sed -n '1p')

{
  printf -- '---\n'
  values_of required-frontmatter | while IFS= read -r field; do
    case "$field" in
      type) printf 'type: %s\n' "$type_name" ;;
      status) printf 'status: %s\n' "$status" ;;
      date|observed|reported|last-reviewed|baseline-date) printf '%s: %s\n' "$field" "$(date +%Y-%m-%d)" ;;
      id) printf 'id: %s\n' "${next:-}" ;;
      *) printf '%s: TODO\n' "$field" ;;
    esac
  done
  printf -- '---\n\n'
  printf '# %s\n\n' "$title"
  printf '%s\n\n' "$(value_of question)"
  values_of heading | while IFS= read -r heading; do
    [ -n "$heading" ] || continue
    printf '## %s\n\n' "$heading"
  done
} >"$target"

printf 'Created %s/%s\n' "$destination" "$name"
printf '  독자: %s\n' "$(value_of readers)"
printf '  답할 질문: %s\n' "$(value_of question)"
printf '  이 뼈대는 아직 구조 검사를 통과하지 않는다. 절을 채운 뒤 engsys docs check 로 확인한다.\n'
