#!/bin/sh

# Check authored documents against the docs-gov document type contracts.
#
# The project contract assigns paths to types. This checker verifies what a machine can
# verify: a declared type that matches the assignment, the status vocabulary, required
# metadata, declared reference targets, a leading summary, and the required sections.
# It does not grade prose or judge whether evidence is sufficient; the editorial review does.
#
# Frozen records keep their original section order, so only presence is required. Paths the
# project lists as deferred keep metadata and reference checks without section checks.
set -eu

fail() { printf 'engsys docs: %s\n' "$*" >&2; exit 2; }
usage() {
  cat <<'EOF'
Usage:
  engsys docs check [--project <directory>] [--path <document>]

  --path checks one document and skips the contract check. An unassigned path is not an
  error: it exits quietly so an editor hook can run on every write.

Types come from the locked docs-gov package. Path assignments, deferrals, and exemptions
come from documentation.authoring in the project contract.
EOF
}

project=$(pwd)
single_path=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project) [ "$#" -ge 2 ] || fail '--project requires a value'; project=$2; shift 2 ;;
    --path) [ "$#" -ge 2 ] || fail '--path requires a value'; single_path=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

system_root=${ENGSYS_SYSTEM_ROOT:?ENGSYS_SYSTEM_ROOT is not set}
types_file="$system_root/packages/docs-gov/document-types.yaml"
[ -f "$types_file" ] || fail "document type contract is missing: $types_file"
[ -d "$project" ] || fail "project does not exist: $project"
project=$(CDPATH= cd -- "$project" && pwd -P)
[ -f "$project/.engsys/project.yaml" ] || fail "project contract not found: $project/.engsys/project.yaml"

work=$(mktemp -d)
trap 'rm -rf "$work"' 0
trap 'exit 129' 1
trap 'exit 130' 2
trap 'exit 143' 15
tab=$(printf '\t')

# Flatten the type contract: "rule<TAB>type<TAB>field<TAB>value",
# "section<TAB>type<TAB>order<TAB>key<TAB>pattern", "alias<TAB>declared<TAB>canonical".
awk '
  function unq(text) {
    gsub(/^[ \t]+|[ \t]+$/, "", text)
    if (text ~ /^\047.*\047$/) { text = substr(text, 2, length(text) - 2); gsub(/\047\047/, "\047", text) }
    return text
  }
  function emit_list(type_name, field, text,   count, parts, index_part, value) {
    sub(/^\[/, "", text); sub(/\]$/, "", text)
    count = split(text, parts, ",")
    for (index_part = 1; index_part <= count; index_part++) {
      value = unq(parts[index_part])
      if (value != "") print "rule\t" type_name "\t" field "\t" value
    }
  }
  /^types:$/ { mode = "types"; next }
  /^aliases:$/ { mode = "aliases"; next }
  /^[A-Za-z]/ { mode = ""; next }
  mode == "aliases" && /^  [A-Za-z0-9_-]+:/ {
    line = $0; sub(/^  /, "", line); position = index(line, ":")
    print "alias\t" substr(line, 1, position - 1) "\t" unq(substr(line, position + 1))
    next
  }
  mode == "types" && /^  [A-Za-z0-9_-]+:$/ {
    name = $0; sub(/^  /, "", name); sub(/:$/, "", name); in_sections = 0; order = 0; next
  }
  mode == "types" && /^    sections:$/ { in_sections = 1; next }
  mode == "types" && /^    [a-z-]+:/ {
    in_sections = 0
    line = $0; sub(/^    /, "", line); position = index(line, ":")
    field = substr(line, 1, position - 1); value = substr(line, position + 1)
    gsub(/^[ \t]+|[ \t]+$/, "", value)
    if (value ~ /^\[/) emit_list(name, field, value)
    else if (value != "") print "rule\t" name "\t" field "\t" unq(value)
    next
  }
  in_sections && /^      - key:/ { line = $0; sub(/^      - key:/, "", line); key = unq(line); order++; next }
  in_sections && /^        pattern:/ {
    line = $0; sub(/^        pattern:/, "", line)
    print "section\t" name "\t" order "\t" key "\t" unq(line)
    next
  }
' "$types_file" >"$work/types"
[ -s "$work/types" ] || fail 'document-types.yaml declares no types'

# Flatten documentation.authoring: "assign<TAB>path<TAB>type", "deferred<TAB>path", "exempt<TAB>path".
awk '
  function unq(text) {
    gsub(/^[ \t]+|[ \t]+$/, "", text)
    if (text ~ /^\047.*\047$/) { text = substr(text, 2, length(text) - 2); gsub(/\047\047/, "\047", text) }
    return text
  }
  /^documentation:$/ { in_documentation = 1; next }
  /^[A-Za-z]/ { in_documentation = 0 }
  in_documentation && /^  authoring:$/ { in_authoring = 1; key = ""; next }
  in_documentation && /^  [a-z-]+:/ { in_authoring = 0 }
  in_authoring && /^    [a-z-]+:/ {
    line = $0; sub(/^    /, "", line); sub(/:.*$/, "", line); key = line; next
  }
  in_authoring && key == "assign" && /^      - path:/ {
    line = $0; sub(/^      - path:/, "", line); pending = unq(line); next
  }
  in_authoring && key == "assign" && /^        type:/ {
    line = $0; sub(/^        type:/, "", line)
    if (pending != "") print "assign\t" pending "\t" unq(line)
    pending = ""; next
  }
  in_authoring && (key == "deferred" || key == "exempt") && /^      - / {
    line = $0; sub(/^      - /, "", line); print key "\t" unq(line); next
  }
' "$project/.engsys/project.yaml" >"$work/authoring"

grep "^assign$tab" "$work/authoring" >"$work/assign" 2>/dev/null || : >"$work/assign"
grep "^deferred$tab" "$work/authoring" >"$work/deferred" 2>/dev/null || : >"$work/deferred"
grep "^exempt$tab" "$work/authoring" >"$work/exempt" 2>/dev/null || : >"$work/exempt"
if [ ! -s "$work/assign" ]; then
  [ -z "$single_path" ] || exit 0
  fail 'project contract declares no documentation.authoring.assign entries'
fi
# An assignment may name a path that holds no document yet. A path that does not exist at all
# is a stale declaration, and every such entry means the check is not looking at anything.
existing_assignments=0
while IFS="$tab" read -r _ pattern _; do
  [ -n "$pattern" ] || continue
  case "$pattern" in
    *[*?]*) existing_assignments=$((existing_assignments + 1)) ;;
    *) [ ! -e "$project/$pattern" ] || existing_assignments=$((existing_assignments + 1)) ;;
  esac
done <"$work/assign"
if [ "$existing_assignments" -eq 0 ]; then
  [ -z "$single_path" ] || exit 0
  fail 'no documentation.authoring.assign path exists; fix the declaration'
fi
if [ -f "$project/.engsys/generated-paths.txt" ]; then
  cp "$project/.engsys/generated-paths.txt" "$work/generated"
else
  : >"$work/generated"
fi

glob_of() {
  case "$1" in
    *[*?]*) printf '%s' "$1" ;;
    *) printf '%s/*' "${1%/}" ;;
  esac
}
listed() {
  # $1 relative path, $2 file of "<key><TAB><pattern>" lines
  while IFS="$tab" read -r _ pattern; do
    [ -n "$pattern" ] || continue
    [ "$1" = "$pattern" ] && return 0
    candidate=$(glob_of "$pattern")
    case "$1" in $candidate) return 0 ;; esac
  done <"$2"
  return 1
}
assigned_type() {
  best_length=0
  best_type=
  while IFS="$tab" read -r _ pattern type_name; do
    [ -n "$pattern" ] || continue
    matched=false
    if [ "$1" = "$pattern" ]; then
      matched=true
    else
      candidate=$(glob_of "$pattern")
      case "$1" in $candidate) matched=true ;; esac
    fi
    if [ "$matched" = true ] && [ "${#pattern}" -gt "$best_length" ]; then
      best_length=${#pattern}
      best_type=$type_name
    fi
  done <"$2"
  printf '%s' "$best_type"
}

# Document facts: "meta<TAB>key<TAB>value", "head<TAB>text", "lead<TAB>0|1".
document_facts() {
  case "$1" in
    *.md) awk '
        NR == 1 && $0 == "---" { in_front = 1; next }
        in_front && $0 == "---" { in_front = 0; next }
        in_front {
          position = index($0, ":")
          if (position > 1) {
            key = substr($0, 1, position - 1); value = substr($0, position + 1)
            gsub(/^[ \t]+|[ \t]+$/, "", key); gsub(/^[ \t]+|[ \t]+$/, "", value)
            if (value ~ /^\047.*\047$/) value = substr(value, 2, length(value) - 2)
            if (value != "") print "meta\t" key "\t" value
          }
          next
        }
        /^# / && !seen_title { seen_title = 1; next }
        /^## / { in_body = 1; title = substr($0, 4); gsub(/^[ \t]+|[ \t]+$/, "", title); print "head\t" title; next }
        /^#{1,6} / { next }
        !in_body && /[^ \t]/ { lead = 1 }
        END { print "lead\t" (lead ? 1 : 0) }
      ' "$1" ;;
    *.html) awk '
        { document = document " " $0 }
        END {
          rest = document
          while (match(rest, /<meta[^>]*name="doc-[A-Za-z-]+"[^>]*>/)) {
            tag = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
            key = tag; sub(/^.*name="doc-/, "", key); sub(/".*$/, "", key)
            if (match(tag, /content="[^"]*"/)) {
              value = substr(tag, RSTART + 9, RLENGTH - 10)
              gsub(/^[ \t]+|[ \t]+$/, "", value)
              if (value != "") print "meta\t" key "\t" value
            }
          }
          total = split(document, parts, /<h2[^>]*>/)
          for (position = 2; position <= total; position++) {
            chunk = parts[position]
            close_at = index(chunk, "</h2>")
            if (close_at == 0) continue
            title = substr(chunk, 1, close_at - 1)
            gsub(/<[^>]*>/, "", title); gsub(/^[ \t]+|[ \t]+$/, "", title)
            print "head\t" title
          }
          print "lead\t" (document ~ /<h1[^>]*>[^<]*[^ \t<][^<]*<\/h1>/ ? 1 : 0)
        }
      ' "$1" ;;
  esac
}

meta_value() { awk -F"$tab" -v key="$2" '$1 == "meta" && $2 == key { print $3; exit }' "$1"; }
rule_values() {
  awk -F"$tab" -v type_name="$2" -v field="$3" '$1 == "rule" && $2 == type_name && $3 == field { print $4 }' "$1"
}

# Reference fields declare the evidence a document depends on. A missing target is a broken record.
reference_fields='spec source supersedes superseded-by current-progress raw-data prototype policy related-adr criteria'
reference_roots='docs/ backend/ frontend/ infra/ spike/ packages/'

: >"$work/findings"
checked=0
deferred_count=0
exempt_count=0
unassigned=0
cd "$project"
if [ -n "$single_path" ]; then
  case "$single_path" in
    "$project"/*) single_path=${single_path#"$project"/} ;;
    /*) exit 0 ;;
  esac
  printf '%s\n' "$single_path" >"$work/paths"
else
  git -c core.quotePath=false ls-files --cached --others --exclude-standard \
    | LC_ALL=C sort -u >"$work/paths"
fi

while IFS= read -r path; do
  case "$path" in .engsys/*) continue ;; *.md|*.html) ;; *) continue ;; esac
  grep -Fxq -- "$path" "$work/generated" && continue
  if listed "$path" "$work/exempt"; then
    exempt_count=$((exempt_count + 1))
    continue
  fi
  expected=$(assigned_type "$path" "$work/assign")
  if [ -z "$expected" ]; then
    unassigned=$((unassigned + 1))
    printf '%s\n' "$path" >>"$work/unassigned"
    continue
  fi
  if [ ! -f "$path" ] || [ -L "$path" ]; then
    [ -z "$single_path" ] || exit 0
    fail "document must be a regular file: $path"
  fi
  checked=$((checked + 1))
  report() { printf '%s: %s\n' "$path" "$1" >>"$work/findings"; }

  document_facts "$path" >"$work/facts"
  declared=$(meta_value "$work/facts" type)
  if [ -z "$declared" ]; then
    report 'no declared document type; add frontmatter `type` or a doc-type meta'
    continue
  fi
  canonical=$(awk -F"$tab" -v declared="$declared" '$1 == "alias" && $2 == declared { print $3; exit }' "$work/types")
  [ -n "$canonical" ] || canonical=$declared
  if ! awk -F"$tab" -v want="$canonical" '$1 == "rule" && $2 == want { found = 1 } END { exit found ? 0 : 1 }' "$work/types"; then
    report "unknown document type: $declared"
    continue
  fi
  if [ "$canonical" != "$expected" ]; then
    report "declared type $canonical does not match the assigned type $expected"
  fi

  status=$(meta_value "$work/facts" status)
  rule_values "$work/types" "$canonical" statuses >"$work/statuses"
  if ! grep -Fxq -- "$status" "$work/statuses"; then
    report "status '$status' is not one of $(tr '\n' ' ' <"$work/statuses")"
  fi

  rule_values "$work/types" "$canonical" required-frontmatter >"$work/required"
  while IFS= read -r field; do
    [ -n "$field" ] || continue
    [ -n "$(meta_value "$work/facts" "$field")" ] \
      || report "required metadata field is missing or empty: $field"
  done <"$work/required"

  for field in $reference_fields; do
    target=$(meta_value "$work/facts" "$field")
    [ -n "$target" ] || continue
    case "$target" in http://*|https://*|*' '*|*'*'*) continue ;; esac
    base=$(dirname "$path")
    for root in $reference_roots; do
      case "$target" in "$root"*) base=. ;; esac
    done
    [ -e "$base/$target" ] || report "$field points at a missing target: $target"
  done

  if listed "$path" "$work/deferred"; then
    deferred_count=$((deferred_count + 1))
    continue
  fi
  [ "$(awk -F"$tab" '$1 == "lead" { print $2; exit }' "$work/facts")" = 1 ] \
    || report 'no leading summary before the first section'

  awk -F"$tab" -v want="$canonical" '$1 == "section" && $2 == want { print $3 "\t" $4 "\t" $5 }' \
    "$work/types" >"$work/sections"
  [ -s "$work/sections" ] || continue
  awk -F"$tab" '$1 == "head" { print $2 }' "$work/facts" >"$work/heads"
  rule_values "$work/types" "$canonical" frozen-status >"$work/frozen"
  frozen=false
  grep -Fxq -- "$status" "$work/frozen" && frozen=true

  # Match each required section at or after the previous match. Independent first-match would
  # let an earlier heading satisfy a later section's pattern and report a false order violation.
  cursor=1
  out_of_order=
  while IFS="$tab" read -r _ key pattern; do
    [ -n "$pattern" ] || continue
    anywhere=$(awk -v pattern="$pattern" 'match($0, pattern) { print NR; exit }' "$work/heads")
    if [ -z "$anywhere" ]; then
      report "missing required section ($key): $pattern"
      continue
    fi
    if [ "$frozen" = true ]; then
      continue
    fi
    position=$(awk -v pattern="$pattern" -v from="$cursor" \
      'NR >= from && match($0, pattern) { print NR; exit }' "$work/heads")
    if [ -z "$position" ]; then
      out_of_order="${out_of_order}${out_of_order:+ }$key"
    else
      cursor=$((position + 1))
    fi
  done <"$work/sections"
  if [ -n "$out_of_order" ]; then
    report "required sections are out of the declared order: $out_of_order"
  fi
done <"$work/paths"

findings=$(grep -c . "$work/findings" || true)
# 통과 여부만 보이면 무엇이 검사 밖에 있는지 알 수 없다. 배정·유예·제외·미배정을 함께 센다.
if [ -n "$single_path" ]; then
  printf 'Document structure: %s assigned documents, %s findings\n' "$checked" "$findings"
else
  printf 'Document structure: %s assigned documents, %s findings' "$checked" "$findings"
  printf ' (절 검사 유예 %s · 검사 제외 %s · 유형 미배정 %s)\n' \
    "$deferred_count" "$exempt_count" "$unassigned"
  if [ "$unassigned" -gt 0 ]; then
    sed -n '1,5p' "$work/unassigned" | sed 's/^/  유형 미배정: /'
    [ "$unassigned" -le 5 ] || printf '  유형 미배정: … 외 %s편\n' "$((unassigned - 5))"
  fi
fi
if [ "$findings" -gt 0 ]; then
  while IFS= read -r finding; do
    printf '  %s\n' "$finding" >&2
  done <"$work/findings"
  exit 1
fi
