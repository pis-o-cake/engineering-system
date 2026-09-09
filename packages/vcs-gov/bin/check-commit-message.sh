#!/bin/sh

# Check one commit message against the vcs-gov contract and the project's declared values.
# Format, length and forbidden trailers are the system's rules. Subject language, ending and
# the scope vocabulary come from the project. "One commit, one purpose" stays with the author.
set -eu

fail_usage() { printf 'engsys vcs: %s\n' "$*" >&2; exit 2; }
usage() {
  cat <<'EOF'
Usage:
  engsys vcs check-message <file> [--project <directory>]

<file> is a commit message file, as a commit-msg hook receives it. A project that declares no
vcs block is not checked.
EOF
}

message=
project=$(pwd)
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project) [ "$#" -ge 2 ] || fail_usage '--project requires a value'; project=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) fail_usage "unknown option: $1" ;;
    *) [ -z "$message" ] || fail_usage 'check-message takes one file'; message=$1; shift ;;
  esac
done
[ -n "$message" ] || fail_usage 'check-message needs a commit message file'
[ -f "$message" ] || exit 0

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

# contract -> "section<TAB>field<TAB>value"; warn entries collapse to "warn<TAB>value<TAB>message".
awk "$unquote_awk"'
  /^[a-z-]+:$/ { section = $0; sub(/:$/, "", section); field = ""; next }
  /^  [a-z-]+:/ {
    line = $0; sub(/^  /, "", line); position = index(line, ":")
    field = substr(line, 1, position - 1); value = unq(substr(line, position + 1))
    if (value != "") print section "\t" field "\t" value
    next
  }
  section == "warn-subject-contains" && /^  - value:/ {
    line = $0; sub(/^  - value:/, "", line); pending = unq(line); next
  }
  section == "warn-subject-contains" && /^    message:/ {
    line = $0; sub(/^    message:/, "", line)
    print "warn\t" pending "\t" unq(line); next
  }
  /^    - / { value = $0; sub(/^    - /, "", value); print section "\t" field "\t" unq(value); next }
' "$contract" >"$work/contract"

# project vcs.commit.* declaration.
awk "$unquote_awk"'
  /^vcs:$/ { in_vcs = 1; next }
  /^[A-Za-z]/ { in_vcs = 0 }
  in_vcs && /^  [a-z-]+:$/ { group = $0; sub(/^  /, "", group); sub(/:$/, "", group); field = ""; next }
  in_vcs && /^    [a-z-]+:/ {
    line = $0; sub(/^    /, "", line); position = index(line, ":")
    field = substr(line, 1, position - 1); value = unq(substr(line, position + 1))
    if (value != "") print group "\t" field "\t" value
    next
  }
  in_vcs && /^      - / { value = $0; sub(/^      - /, "", value); print group "\t" field "\t" unq(value); next }
' "$declaration" >"$work/declared"

contract_values() { awk -F"$tab" -v s="$1" -v f="$2" '$1 == s && $2 == f { print $3 }' "$work/contract"; }
declared_values() { awk -F"$tab" -v g="$1" -v f="$2" '$1 == g && $2 == f { print $3 }' "$work/declared"; }
first_declared() { declared_values "$1" "$2" | sed -n '1p'; }

# 주석과 빈 줄을 뺀 첫 줄이 헤더다.
header=$(grep -v '^#' "$message" | sed '/^[[:space:]]*$/d' | sed -n '1p')
[ -n "$header" ] || exit 0
contract_values commit skip-headers >"$work/skip"
while IFS= read -r prefix; do
  [ -n "$prefix" ] || continue
  case "$header" in "$prefix"*) exit 0 ;; esac
done <"$work/skip"

types=$(contract_values commit types | tr '\n' '|' | sed 's/|$//')
ending=$(first_declared commit subject-ending)
[ -n "$ending" ] || ending=noun
guidance=$(contract_values "subject-ending-$ending" guidance | sed -n '1p')
[ -n "$guidance" ] || fail_usage "unknown subject-ending: $ending"

reject() {
  printf '\ncommit-msg: %s\n\n' "$1" >&2
  printf '  받은 헤더: %s\n\n' "$header" >&2
  printf '  형식: %s\n' "$(contract_values commit header | sed -n '1p')" >&2
  printf '  type: %s\n' "$(contract_values commit types | tr '\n' ' ')" >&2
  printf '  subject: %s\n' "$guidance" >&2
  scopes=$(declared_values commit scopes | tr '\n' ' ')
  [ -z "$scopes" ] || printf '  scope: %s\n' "$scopes" >&2
  printf '\n  계약: packages/vcs-gov/commit-contract.yaml · 선언: .engsys/project.yaml 의 vcs\n\n' >&2
  exit 1
}

printf '%s' "$header" | grep -Eq "^($types)(\([a-z0-9-]+\))?!?: .+" \
  || reject "헤더가 <type>(<scope>): <subject> 형식이 아니다"

# 선언한 scope 목록이 있으면 그 안에서만 쓴다. 새 scope 는 선언에 추가한다.
declared_values commit scopes >"$work/scopes"
if [ -s "$work/scopes" ]; then
  case "$header" in
    *'('*')'*)
      used=${header#*\(}
      used=${used%%\)*}
      grep -Fxq -- "$used" "$work/scopes" || reject "선언하지 않은 scope 다: $used"
      ;;
  esac
fi

subject=${header#*: }
limit=$(contract_values commit subject-max-characters | sed -n '1p')
# IMPORTANT: 한글은 UTF-8 에서 3바이트다. C 로케일의 wc -m 은 바이트를 세므로 정상 메시지가
#            3배로 계산돼 전부 막힌다. python3 가 있으면 그것으로 세고 없으면 UTF-8 로케일로 떨어진다.
if command -v python3 >/dev/null 2>&1; then
  length=$(printf '%s' "$subject" | python3 -c 'import sys; print(len(sys.stdin.read()))')
else
  length=$(printf '%s' "$subject" | LC_ALL=C.UTF-8 wc -m | tr -d ' ')
fi
[ "$length" -le "$limit" ] || reject "subject 가 ${length}자다. ${limit}자 이내로 줄인다"

case "$subject" in *.) reject 'subject 끝에 마침표를 붙이지 않는다' ;; esac

contract_values "subject-ending-$ending" forbidden >"$work/endings"
while IFS= read -r bad; do
  [ -n "$bad" ] || continue
  case "$subject" in *"$bad") reject "$guidance" ;; esac
done <"$work/endings"

contract_values commit forbidden-trailers >"$work/trailers"
while IFS= read -r trailer; do
  [ -n "$trailer" ] || continue
  if grep -qi "^$trailer:" "$message"; then
    reject "$trailer 는 넣지 않는다"
  fi
done <"$work/trailers"

# 헤더 다음 줄이 비어 있지 않으면 git log --oneline 이 body 첫 줄까지 제목으로 읽는다.
if [ "$(contract_values commit blank-line-after-header | sed -n '1p')" = true ]; then
  second=$(grep -v '^#' "$message" | sed -n '2p')
  [ -z "$second" ] || reject '헤더와 body 사이에 빈 줄이 필요하다'
fi

# 막지 않고 알린다. 판정이 아니라 커밋을 쪼갤 신호다.
awk -F"$tab" '$1 == "warn" { print $2 "\t" $3 }' "$work/contract" >"$work/warnings"
while IFS="$tab" read -r needle note; do
  [ -n "$needle" ] || continue
  case "$subject" in
    *"$needle"*) printf 'commit-msg: %s\n            그대로 진행한다.\n' "$note" >&2 ;;
  esac
done <"$work/warnings"

exit 0
