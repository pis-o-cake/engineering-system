#!/bin/sh

# Check one merge request body against the vcs-gov contract. Section headings, their order and
# the forbidden phrases are machine-decidable, so they are enforced here. The writing rules and
# the rest of `excluded` stay with the author and the reviewer.
set -eu

fail_usage() { printf 'engsys vcs: %s\n' "$*" >&2; exit 2; }
usage() {
  cat <<'EOF'
Usage:
  engsys vcs check-merge-request <file> [--title <text>] [--project <directory>]

<file> holds the merge request body as it will be sent. Pass --title to check the title form
too. A project that declares no vcs.merge-request is not checked.
EOF
}

body=
title=
project=$(pwd)
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project) [ "$#" -ge 2 ] || fail_usage '--project requires a value'; project=$2; shift 2 ;;
    --title) [ "$#" -ge 2 ] || fail_usage '--title requires a value'; title=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) fail_usage "unknown option: $1" ;;
    *) [ -z "$body" ] || fail_usage 'check-merge-request takes one file'; body=$1; shift ;;
  esac
done
[ -n "$body" ] || fail_usage 'check-merge-request needs a body file'
[ -f "$body" ] || fail_usage "body file does not exist: $body"

system_root=${ENGSYS_SYSTEM_ROOT:?ENGSYS_SYSTEM_ROOT is not set}
contract="$system_root/packages/vcs-gov/commit-contract.yaml"
[ -f "$contract" ] || fail_usage "commit contract is missing: $contract"
[ -d "$project" ] || fail_usage "project does not exist: $project"
project=$(CDPATH= cd -- "$project" && pwd -P)
declaration="$project/.engsys/project.yaml"
[ -f "$declaration" ] || exit 0
grep -q '^vcs:' "$declaration" || exit 0
# merge-request 를 선언하지 않은 프로젝트는 판정 대상이 아니다. 선언이 없으면 도구는 답하지 않는다.
awk '/^vcs:$/ { in_vcs = 1; next } /^[A-Za-z]/ { in_vcs = 0 }
  in_vcs && /^  merge-request:$/ { found = 1 } END { exit found ? 0 : 1 }' "$declaration" || exit 0

work=$(mktemp -d)
trap 'rm -rf "$work"' 0
trap 'exit 129' 1
trap 'exit 130' 2
trap 'exit 143' 15
tab=$(printf '\t')

unquote_awk='
  function unq(text) {
    gsub(/^[ \t]+|[ \t]+$/, "", text)
    if (text ~ /^\047.*\047$/) { text = substr(text, 2, length(text) - 2); gsub(/\047\047/, "\047", text) }
    return text
  }'

# merge-request 블록만 뽑아 "kind<TAB>value<TAB>message" 로 편다.
awk "$unquote_awk"'
  /^merge-request:$/ { in_mr = 1; next }
  /^[a-z-]/ { in_mr = 0 }
  !in_mr { next }
  /^  section-heading-prefix:/ {
    line = $0; sub(/^  section-heading-prefix:/, "", line); print "prefix\t" unq(line) "\t"; next
  }
  /^      heading:/ {
    line = $0; sub(/^      heading:/, "", line); print "heading\t" unq(line) "\t"; next
  }
  /^      question:/ {
    line = $0; sub(/^      question:/, "", line); print "question\t" unq(line) "\t"; next
  }
  /^  unresolved-needs-link:$/ { in_unresolved = 1; next }
  /^  forbidden-body-contains:$/ { in_forbidden = 1; next }
  /^  [a-z-]+:/ { in_forbidden = 0; in_unresolved = 0 }
  in_unresolved && /^    section:/ {
    line = $0; sub(/^    section:/, "", line); print "unresolved-section\t" unq(line) "\t"; next
  }
  in_unresolved && /^    message:/ {
    line = $0; sub(/^    message:/, "", line); print "unresolved-message\t" unq(line) "\t"; next
  }
  in_unresolved && /^    signals:$/ { list = "unresolved-signal"; next }
  in_unresolved && /^    link-patterns:$/ { list = "unresolved-link"; next }
  in_unresolved && /^      - / { line = $0; sub(/^      - /, "", line); print list "\t" unq(line) "\t"; next }
  in_forbidden && /^    - value:/ {
    line = $0; sub(/^    - value:/, "", line); pending = unq(line); next
  }
  in_forbidden && /^      message:/ {
    line = $0; sub(/^      message:/, "", line); print "forbidden\t" pending "\t" unq(line); next
  }
' "$contract" >"$work/contract"

contract_values() { awk -F"$tab" -v k="$1" '$1 == k { print $2 }' "$work/contract"; }

prefix=$(contract_values prefix | sed -n '1p')
[ -n "$prefix" ] || prefix='## '
contract_values heading >"$work/headings"
contract_values question >"$work/questions"
[ -s "$work/headings" ] || fail_usage 'the contract declares no merge-request sections'

findings=0
report() {
  findings=$((findings + 1))
  printf 'merge-request: %s\n' "$1" >&2
}

# 본문에 실제로 있는 절 제목을 순서대로 뽑는다.
awk -v prefix="$prefix" '
  index($0, prefix) == 1 { line = substr($0, length(prefix) + 1); sub(/[ \t]+$/, "", line); print line }
' "$body" >"$work/present"

# 선언한 제목이 전부, 선언한 순서대로 있어야 한다.
missing=0
while IFS= read -r heading; do
  [ -n "$heading" ] || continue
  grep -Fxq -- "$heading" "$work/present" || { report "절이 없다: $prefix$heading"; missing=1; }
done <"$work/headings"

if [ "$missing" -eq 0 ]; then
  grep -Fxf "$work/headings" "$work/present" >"$work/declared-order" || :
  cmp -s "$work/headings" "$work/declared-order" \
    || report "절 순서가 계약과 다르다: $(tr '\n' ' ' <"$work/declared-order")"
fi

# 선언 밖의 절 제목은 쓰지 않는다.
while IFS= read -r heading; do
  [ -n "$heading" ] || continue
  grep -Fxq -- "$heading" "$work/headings" || report "선언하지 않은 절 제목이다: $prefix$heading"
done <"$work/present"

# 절 제목만 있고 내용이 없으면 리뷰어는 그 항목을 검토했는지 알 수 없다. 없으면 없음으로 적는다.
while IFS= read -r heading; do
  [ -n "$heading" ] || continue
  grep -Fxq -- "$heading" "$work/present" || continue
  awk -v prefix="$prefix" -v want="$heading" '
    index($0, prefix) == 1 {
      line = substr($0, length(prefix) + 1); sub(/[ \t]+$/, "", line)
      inside = (line == want); next
    }
    inside && $0 ~ /[^ \t]/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$body" || report "절이 비어 있다: $prefix$heading"
done <"$work/headings"

# 자동 생성 서명과 도구 표기는 본문에 넣지 않는다.
awk -F"$tab" '$1 == "forbidden" { print $2 "\t" $3 }' "$work/contract" >"$work/forbidden"
while IFS="$tab" read -r needle note; do
  [ -n "$needle" ] || continue
  grep -Fq -- "$needle" "$body" && report "$note: $needle"
done <"$work/forbidden"

# 후속 작업이 남았다고 쓰면서 어디서 추적하는지 적지 않으면 그 항목은 이 본문에서만 산다.
unresolved_section=$(contract_values unresolved-section | sed -n '1p')
if [ -n "$unresolved_section" ] && grep -Fxq -- "$unresolved_section" "$work/present"; then
  awk -v prefix="$prefix" -v want="$unresolved_section" '
    index($0, prefix) == 1 {
      line = substr($0, length(prefix) + 1); sub(/[ \t]+$/, "", line)
      inside = (line == want); next
    }
    inside { print }
  ' "$body" >"$work/unresolved-body"
  contract_values unresolved-signal >"$work/signals"
  found_signal=
  while IFS= read -r signal; do
    [ -n "$signal" ] || continue
    grep -Fq -- "$signal" "$work/unresolved-body" && { found_signal=$signal; break; }
  done <"$work/signals"
  if [ -n "$found_signal" ]; then
    contract_values unresolved-link >"$work/links"
    found_link=false
    while IFS= read -r pattern; do
      [ -n "$pattern" ] || continue
      grep -Fq -- "$pattern" "$work/unresolved-body" && { found_link=true; break; }
    done <"$work/links"
    [ "$found_link" = true ] \
      || report "$(contract_values unresolved-message | sed -n '1p') (\"$found_signal\")"
  fi
fi

# title 은 commit 헤더와 같은 형식이다. 판정은 commit 검사기가 그대로 한다.
if [ -n "$title" ]; then
  printf '%s\n' "$title" >"$work/title-message"
  ENGSYS_SYSTEM_ROOT="$system_root" \
    sh "$system_root/packages/vcs-gov/bin/check-commit-message.sh" "$work/title-message" \
      --project "$project" >/dev/null 2>"$work/title-error" \
    || { report 'title 이 commit 헤더 형식이 아니다'; sed 's/^/  /' "$work/title-error" >&2; }
fi

[ "$findings" -eq 0 ] && exit 0

printf '\n  선언한 절 제목과 순서:\n' >&2
paste -d"$tab" "$work/headings" "$work/questions" 2>/dev/null \
  | awk -F"$tab" -v prefix="$prefix" '{ printf "    %s%s — %s\n", prefix, $1, $2 }' >&2
printf '\n  계약: packages/vcs-gov/commit-contract.yaml 의 merge-request\n\n' >&2
exit 1
