#!/bin/sh

# Record a review of one document; check review coverage without judging prose.
set -eu

fail() { printf 'engsys review: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'EOF'
Usage:
  engsys review status --scope <path> [--scope <path> ...] [--revision <commit>]
  engsys review check --scope <path> [--scope <path> ...] [--revision <commit>]
  engsys review record --document <path> --blob <hash> --reviewer <name>
                      --audience <readers> --purpose <question> --notes-file <file>
All commands accept --project <directory>. Scopes are literal files or directories.
status/check cover Markdown and HTML, excluding declared generated documents.
record accepts exactly one document, after a full editorial review of that blob.
EOF
}
relative_path() {
  case "$1" in
    ''|/*|..|../*|*/../*|*/..|./*|*/./*|*//*|-*|*\\*|*\"*|*\'*) fail "unsupported relative path: $1" ;;
  esac
  if printf '%s' "$1" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    fail 'paths and review fields cannot contain control characters'
  fi
}
single_line() {
  printf '%s' "$2" | grep -q '[^[:space:]]' || fail "$1 must not be empty"
  if printf '%s' "$2" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    fail "$1 must be a single line"
  fi
}
need_value() { [ "$#" -ge 2 ] || fail "$1 requires a value"; }

action=${1:-help}
[ "$#" -eq 0 ] || shift
project=$(pwd)
scopes=
revision=
document=
expected_blob=
reviewer=
audience=
purpose=
notes=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project) need_value "$@"; project=$2; shift 2 ;;
    --scope)
      need_value "$@"; scope=${2%/}; relative_path "$scope"
      scopes="${scopes}${scopes:+
}$scope"; shift 2 ;;
    --revision) need_value "$@"; revision=$2; shift 2 ;;
    --document)
      need_value "$@"; [ -z "$document" ] || fail 'record accepts one document only'
      document=$2; shift 2 ;;
    --blob) need_value "$@"; expected_blob=$2; shift 2 ;;
    --reviewer) need_value "$@"; reviewer=$2; shift 2 ;;
    --audience) need_value "$@"; audience=$2; shift 2 ;;
    --purpose) need_value "$@"; purpose=$2; shift 2 ;;
    --notes-file) need_value "$@"; notes=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done
case "$action" in status|check|record) ;; help) usage; exit 0 ;; *) fail "unknown action: $action" ;; esac

[ -d "$project" ] || fail "project does not exist: $project"
project=$(CDPATH= cd -- "$project" && pwd -P)
git_root=$(git -C "$project" rev-parse --show-toplevel) || fail 'project must be a Git worktree'
[ "$project" = "$(CDPATH= cd -- "$git_root" && pwd -P)" ] || fail '--project must be the repository root'
# The adapter check catches stale generated-path declarations before exclusions are used.
"$ENGSYS_SYSTEM_ROOT/bin/engsys" check --project "$project" >/dev/null
grep -q '^  docs-gov:$' "$project/.engsys/lock.yaml" || fail 'docs-gov is not enabled in the project lock'

temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' 0
trap 'exit 129' 1
trap 'exit 130' 2
trap 'exit 143' 15
if [ -n "$notes" ]; then
  [ -f "$notes" ] || fail "review notes do not exist: $notes"
  cp "$notes" "$temporary/notes"
fi
cd "$project"
if [ -n "$revision" ]; then
  case "$revision" in -*|*[!A-Za-z0-9_./-]*) fail 'unsupported revision' ;; esac
  revision=$(git rev-parse --verify "$revision^{commit}") || fail 'revision is not a commit'
  git show "$revision:.engsys/generated-paths.txt" >"$temporary/generated" \
    || fail 'revision has no generated-paths contract'
  git show "$revision:.engsys/project.yaml" >"$temporary/contract" \
    || fail 'revision has no project contract'
else
  cp .engsys/generated-paths.txt "$temporary/generated"
  cp .engsys/project.yaml "$temporary/contract"
fi

# documentation.review.scopes 는 검사 범위의 정본이다. 프로젝트 hook 이 같은 목록을 다시
# 파싱하지 않도록, --scope 를 주지 않으면 계약에서 읽는다.
contract_review_scopes() {
  awk '
    /^documentation:$/ { in_documentation = 1; next }
    /^[A-Za-z]/ { in_documentation = 0 }
    in_documentation && /^  review:$/ { in_review = 1; next }
    in_documentation && /^  [a-z-]+:/ { in_review = 0 }
    in_review && /^    scopes:$/ { in_scopes = 1; next }
    in_review && /^    [a-z-]+:/ { in_scopes = 0 }
    in_scopes && /^      - / {
      value = $0; sub(/^      - /, "", value)
      gsub(/^[ \t]+|[ \t]+$/, "", value)
      if (value ~ /^\047.*\047$/) { value = substr(value, 2, length(value) - 2); gsub(/\047\047/, "\047", value) }
      print value
    }
  ' "$temporary/contract"
}

generated() { grep -Fxq -- "$1" "$temporary/generated"; }
current_blob() {
  [ -f "$1" ] && [ ! -L "$1" ] || fail "document must be a regular file: $1"
  parent=$(CDPATH= cd -- "$(dirname "$1")" && pwd -P)
  case "$parent/" in "$project/"*) ;; *) fail "document leaves the project: $1" ;; esac
  git hash-object --no-filters -- "$1"
}
receipt_path() { printf '.engsys/reviews/%s.review' "$1"; }
safe_receipt_destination() {
  [ ! -L "$1" ] || fail 'review receipt must not be a symlink'
  ancestor=$(dirname "$1")
  while [ ! -d "$ancestor" ]; do ancestor=$(dirname "$ancestor"); done
  ancestor=$(CDPATH= cd -- "$ancestor" && pwd -P)
  case "$ancestor/" in "$project/"*) ;; *) fail 'review directory leaves the project' ;; esac
}
receipt_valid() {
  awk -v document="$1" -v blob="$2" '
    !body && /^$/ { body = 1; next }
    !body {
      split_at = index($0, ": ")
      if (!split_at) { invalid = 1; next }
      key = substr($0, 1, split_at - 1)
      if (key in fields) invalid = 1
      fields[key] = substr($0, split_at + 2)
      next
    }
    body && /[^[:space:]]/ { notes = 1 }
    END {
      if (invalid || !notes || fields["engsys-document-review"] != "1" ||
          fields["document"] != document || fields["blob"] != blob ||
          fields["decision"] != "pass" || fields["reviewer"] !~ /[^[:space:]]/ ||
          fields["audience"] !~ /[^[:space:]]/ || fields["purpose"] !~ /[^[:space:]]/)
        exit 1
    }
  ' "$3"
}

if [ "$action" = record ]; then
  [ -z "$scopes$revision" ] || fail 'record does not accept scopes or a revision'
  relative_path "$document"
  case "$document" in *.md|*.html) ;; *) fail 'record expects a Markdown or HTML document' ;; esac
  case "$document" in .engsys/*) fail 'review receipts are not editorial documents' ;; esac
  generated "$document" && fail 'generated documents must be reviewed through their generator'
  single_line reviewer "$reviewer"
  single_line audience "$audience"
  single_line purpose "$purpose"
  [ -f "$temporary/notes" ] && grep -q '[^[:space:]]' "$temporary/notes" \
    || fail '--notes-file must contain document-specific review observations'
  blob=$(current_blob "$document")
  [ "$blob" = "$expected_blob" ] || fail 'document changed or --blob is missing; review the current content again'
  receipt=$(receipt_path "$document")
  safe_receipt_destination "$receipt"
  {
    printf 'engsys-document-review: 1\ndocument: %s\nblob: %s\ndecision: pass\n' "$document" "$blob"
    printf 'reviewer: %s\naudience: %s\npurpose: %s\n\n' "$reviewer" "$audience" "$purpose"
    cat "$temporary/notes"
    printf '\n'
  } >"$temporary/receipt"
  receipt_valid "$document" "$blob" "$temporary/receipt" || fail 'invalid review record'
  [ "$(current_blob "$document")" = "$blob" ] || fail 'document changed while recording the review'
  mkdir -p "$(dirname "$receipt")"
  cp "$temporary/receipt" "$receipt"
  printf 'Recorded editorial review: %s\n' "$document"
  exit 0
fi

if [ -z "$scopes" ]; then
  scopes=$(contract_review_scopes)
  [ -n "$scopes" ] \
    || fail 'pass --scope or declare documentation.review.scopes in the project contract'
  while IFS= read -r scope; do
    [ -n "$scope" ] || continue
    relative_path "${scope%/}"
  done <<EOF
$scopes
EOF
fi
[ -z "$document$expected_blob$reviewer$audience$purpose$notes" ] || fail 'status/check do not accept record fields'
printf '%s\n' "$scopes" >"$temporary/scopes"
: >"$temporary/paths"
while IFS= read -r scope; do
  if [ -n "$revision" ]; then
    git cat-file -e "$revision:$scope" || fail "scope does not exist in revision: $scope"
    git -c core.quotePath=false ls-tree -r --name-only "$revision" -- ":(literal)$scope"
  else
    [ -e "$scope" ] || fail "scope does not exist: $scope"
    git -c core.quotePath=false ls-files --cached --others --exclude-standard -- ":(literal)$scope"
  fi
done <"$temporary/scopes" >"$temporary/paths"
LC_ALL=C sort -u "$temporary/paths" >"$temporary/sorted"
pending=0
checked=0
while IFS= read -r path; do
  relative_path "$path"
  case "$path" in .engsys/*) continue ;; *.md|*.html) ;; *) continue ;; esac
  generated "$path" && continue
  receipt=$(receipt_path "$path")
  if [ -n "$revision" ]; then
    mode=$(git ls-tree "$revision" -- ":(literal)$path" | cut -d ' ' -f1)
    case "$mode" in 100644|100755) ;; *) fail "document must be a regular file: $path" ;; esac
    blob=$(git rev-parse "$revision:$path")
    if ! git show "$revision:$receipt" >"$temporary/receipt" 2>/dev/null; then
      : >"$temporary/receipt"
    fi
  else
    [ -e "$path" ] || continue
    blob=$(current_blob "$path")
    if [ -f "$receipt" ] && [ ! -L "$receipt" ]; then
      cp "$receipt" "$temporary/receipt"
    else
      : >"$temporary/receipt"
    fi
  fi
  checked=$((checked + 1))
  if receipt_valid "$path" "$blob" "$temporary/receipt"; then
    [ "$action" != status ] || printf 'reviewed\t%s\t%s\n' "$blob" "$path"
  else
    printf 'needs-review\t%s\t%s\n' "$blob" "$path"
    pending=$((pending + 1))
  fi
done <"$temporary/sorted"
[ "$checked" -gt 0 ] || fail 'scopes contain no authored Markdown or HTML documents'
printf 'Editorial review coverage: %s documents, %s pending\n' "$checked" "$pending"
if [ "$action" = check ] && [ "$pending" -gt 0 ]; then
  fail 'read and review each pending document; a content hash is not a prose-quality score'
fi
