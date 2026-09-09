#!/bin/sh

# 뼈대는 유형·번호·metadata·필수 절 제목을 대신 채운다. 내용은 대신 쓰지 않으므로 그대로는
# 구조 검사를 통과하지 않는다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0
project="$temporary/project"
mkdir -p "$project/docs/adr" "$project/docs/reports"
git -C "$project" init -q
"$system_root/bin/engsys" init --project "$project" --verify true >/dev/null 2>&1
cat >>"$project/.engsys/project.yaml" <<'EOF'
  authoring:
    assign:
      - path: 'docs/adr'
        type: 'decision-record'
      - path: 'docs/reports'
        type: 'brief'
EOF
"$system_root/bin/engsys" check --project "$project" >/dev/null

new() { "$system_root/bin/engsys" docs new --project "$project" "$@" \
  >"$temporary/out" 2>"$temporary/err"; }

# 배정한 경로를 찾아 번호를 붙인다.
new --type decision-record cache-strategy
grep -Fq 'Created docs/adr/0001-cache-strategy.md' "$temporary/out"
grep -Fq '독자: 기술 책임자와 유지보수자' "$temporary/out"
grep -Fq '구조 검사를 통과하지 않는다' "$temporary/out"

created="$project/docs/adr/0001-cache-strategy.md"
grep -Fxq 'type: decision-record' "$created"
grep -Fxq 'status: proposed' "$created"
grep -Eq '^date: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$created"
grep -Fxq '## 결정' "$created"
grep -Fxq '## 배경과 제약' "$created"
grep -Fxq '## 근거와 대안' "$created"
grep -Fxq '## 영향' "$created"

# 절이 비어 있으므로 구조 검사는 실패한다. 뼈대는 타이핑만 줄인다.
if "$system_root/bin/engsys" docs check --project "$project" \
    --path docs/adr/0001-cache-strategy.md >"$temporary/out" 2>&1; then
  printf 'an empty skeleton must not pass the structure check\n' >&2
  exit 1
fi
grep -Fq 'required section has no content' "$temporary/out"

# 번호는 앞의 0 때문에 8진수로 읽히지 않는다.
for slug in a b c d e f g h; do new --type decision-record "$slug"; done
: >"$project/docs/adr/0009-manual.md"
new --type decision-record after-nine
grep -Fq 'Created docs/adr/0010-after-nine.md' "$temporary/out"

# 날짜 형식 유형은 파일명에 날짜가 붙는다.
new --type brief weekly-status
grep -Eq "Created docs/reports/[0-9]{4}-[0-9]{2}-[0-9]{2}-weekly-status\.md" "$temporary/out"

# 배정이 없는 유형은 경로를 요구한다.
if new --type runbook deploy; then
  printf 'a type without an assignment needs an explicit path\n' >&2
  exit 1
fi
grep -Fq 'no path is assigned to runbook' "$temporary/err"
new --type runbook --path docs deploy
grep -Fq 'Created docs/deploy.md' "$temporary/out"
grep -Fxq '## 실행 전 확인' "$project/docs/deploy.md"

# 번호가 붙지 않는 유형은 같은 이름을 덮지 않는다.
if new --type runbook --path docs deploy; then
  printf 'the scaffold must not overwrite an existing document\n' >&2
  exit 1
fi
grep -Fq 'already exists' "$temporary/err"

# 알 수 없는 유형과 잘못된 slug 는 거부한다.
if new --type novel-record x; then exit 1; fi
grep -Fq 'unknown document type: novel-record' "$temporary/err"
if new --type decision-record 'Cache Strategy'; then exit 1; fi
grep -Fq 'slug uses lowercase letters' "$temporary/err"

printf 'ok the scaffold fills the form and leaves the writing\n'
