#!/bin/sh

# 구조 검사가 실제 누락을 잡는지 확인한다. 문체는 판정 대상이 아니다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' 0
project="$temporary/project"
mkdir -p "$project/docs/reports" "$project/docs/adr" "$project/docs/external"
git -C "$project" init -q
git -C "$project" config user.name 'Structure Fixture'
git -C "$project" config user.email 'fixture@example.test'
"$system_root/bin/engsys" init --project "$project" --verify true \
  --generated docs/generated.md true >/dev/null
printf '# Generated\n' >"$project/docs/generated.md"

cat >>"$project/.engsys/project.yaml" <<'EOF'
  authoring:
    assign:
      - path: 'docs/adr'
        type: 'decision-record'
      - path: 'docs/reports/*.md'
        type: 'experiment-report'
      - path: 'docs/reports/*.html'
        type: 'brief'
    exempt:
      - 'docs/external'
    deferred:
      - 'docs/reports/2026-01-01-legacy.md'
EOF

docs_check() { "$system_root/bin/engsys" docs check --project "$project"; }
reject() {
  if docs_check >"$temporary/result" 2>&1; then
    printf 'Unexpected structure success\n' >&2
    cat "$temporary/result" >&2
    exit 1
  fi
}
accept() { docs_check >"$temporary/result" 2>&1 || { cat "$temporary/result" >&2; exit 1; }; }

report="$project/docs/reports/2026-02-01-latency.md"
write_report() {
  cat >"$report" <<EOF
---
type: experiment-report
status: $1
observed: 2026-02-01
---

# 응답시간 실측

동시 16으로 10~50쪽을 재면 배치당 10초가 걸린다.
$2
EOF
}

complete_body='
## 0. 결론

10쪽당 8초다.

## 1. 측정 방법

같은 문서를 앞 N쪽만 잘라 3회차 반복했다.

## 2. 결과

10쪽 10.2초 · 50쪽 43.8초.

## 3. 한계

빈 저장소에서 쟀다.
'

# 필수 절이 빠지면 실패한다.
write_report archived '
## 0. 결론

10쪽당 8초다.
'
reject
grep -Fq 'missing required section (method)' "$temporary/result"
grep -Fq 'missing required section (limits)' "$temporary/result"

# 필수 절을 채우면 통과한다.
write_report archived "$complete_body"
accept
grep -Fq '1 assigned documents, 0 findings' "$temporary/result"

# 필수 metadata 가 비면 실패한다.
sed '/^observed:/d' "$report" >"$report.tmp" && mv "$report.tmp" "$report"
reject
grep -Fq 'required metadata field is missing or empty: observed' "$temporary/result"
write_report archived "$complete_body"

# 알 수 없는 status 와 type 은 실패한다.
sed 's/^status: archived$/status: done/' "$report" >"$report.tmp" && mv "$report.tmp" "$report"
reject
grep -Fq "status 'done' is not one of" "$temporary/result"
write_report archived "$complete_body"
sed 's/^type: experiment-report$/type: novel-record/' "$report" >"$report.tmp" && mv "$report.tmp" "$report"
reject
grep -Fq 'unknown document type: novel-record' "$temporary/result"

# 배정과 다른 유형을 선언해도 실패한다.
sed 's/^type: novel-record$/type: review-report/' "$report" >"$report.tmp" && mv "$report.tmp" "$report"
reject
grep -Fq 'does not match the assigned type experiment-report' "$temporary/result"
write_report archived "$complete_body"

# 근거로 선언한 경로가 없으면 실패한다.
sed 's/^observed: 2026-02-01$/observed: 2026-02-01\nsource: docs\/reports\/missing.md/' "$report" \
  >"$report.tmp" && mv "$report.tmp" "$report"
reject
grep -Fq 'source points at a missing target' "$temporary/result"
write_report archived "$complete_body"

# 도입 문단이 없으면 실패한다 — 첫 절 전에 결론을 적는다.
printf -- '---\ntype: experiment-report\nstatus: archived\nobserved: 2026-02-01\n---\n\n# 제목\n%s' \
  "$complete_body" >"$report"
reject
grep -Fq 'no leading summary' "$temporary/result"
write_report archived "$complete_body"

# 유예 목록의 기존 문서는 절 검사를 받지 않되 metadata 는 검사한다.
legacy="$project/docs/reports/2026-01-01-legacy.md"
printf -- '---\ntype: experiment-report\nstatus: archived\nobserved: 2026-01-01\n---\n\n# 옛 기록\n\n결과만 있다.\n' >"$legacy"
accept
grep -Fq '2 assigned documents, 0 findings' "$temporary/result"
sed '/^observed:/d' "$legacy" >"$legacy.tmp" && mv "$legacy.tmp" "$legacy"
reject
grep -Fq '2026-01-01-legacy.md: required metadata field is missing or empty: observed' "$temporary/result"
rm "$legacy"

# 동결 기록은 절 순서를 강제하지 않고, 진행 중 문서는 강제한다.
out_of_order='
## 1. 측정 방법

3회차 반복.

## 0. 결론

10쪽당 8초다.

## 2. 결과

43.8초.

## 3. 한계

빈 저장소.
'
write_report archived "$out_of_order"
accept
write_report draft "$out_of_order"
reject
grep -Fq 'out of the declared order' "$temporary/result"
write_report archived "$complete_body"

# 앞 절의 제목이 뒤 절의 패턴에도 걸리는 경우를 순서 위반으로 오탐하지 않는다.
write_report draft '
## 0. 결론과 적용 범위

10쪽당 8초이고 색인 경로에만 적용한다.

## 1. 측정 방법

같은 문서를 앞 N쪽만 잘라 3회차 반복했다.

## 2. 결과

10쪽 10.2초 · 50쪽 43.8초.

## 3. 한계

빈 저장소에서 쟀다.
'
accept
grep -Fq '1 assigned documents, 0 findings' "$temporary/result"
write_report archived "$complete_body"

# 배정 밖 경로와 exempt 경로, 생성 문서는 대상이 아니다.
printf '# 외부 원문\n' >"$project/docs/external/notice.md"
printf '# 배정 없음\n' >"$project/docs/loose.md"
accept
grep -Fq '1 assigned documents' "$temporary/result"

# alias 로 선언한 옛 유형 값도 받는다.
sed 's/^type: experiment-report$/type: measurement-record/' "$report" >"$report.tmp" && mv "$report.tmp" "$report"
accept

# HTML 은 doc-* meta 로 유형을 선언한다.
brief="$project/docs/reports/2026-02-02-brief.html"
printf '<h1>진도 보고</h1>\n<p>일정은 유지된다.</p>\n' >"$brief"
reject
grep -Fq 'no declared document type' "$temporary/result"
printf '<meta name="doc-type" content="brief">\n<meta name="doc-status" content="archived">\n<h1>진도 보고</h1>\n' >"$brief"
reject
grep -Fq 'required metadata field is missing or empty: reported' "$temporary/result"
printf '<meta name="doc-type" content="brief">\n<meta name="doc-status" content="archived">\n<meta name="doc-reported" content="2026-02-02">\n<h1>진도 보고</h1>\n' >"$brief"
reject
grep -Fq 'missing required section (summary)' "$temporary/result"
cat >"$brief" <<'HTML'
<meta name="doc-type" content="brief">
<meta name="doc-status" content="archived">
<meta name="doc-reported" content="2026-02-02">
<h1>진도 보고</h1>
<p>통합시험 일정은 유지된다.</p>
<h2>보고 요약</h2>
<p>색인 기능은 9월 12일 기준으로 완료했다.</p>
<h2>주요 결과와 영향</h2>
<p>응답시간이 기준의 2배여서 검수 일정에 영향을 준다.</p>
HTML
accept

# 배정 선언이 없으면 검사를 통과시키지 않고 오류로 끝낸다.
mkdir -p "$temporary/bare"
git -C "$temporary/bare" init -q
"$system_root/bin/engsys" init --project "$temporary/bare" --verify true >/dev/null
if "$system_root/bin/engsys" docs check --project "$temporary/bare" >"$temporary/result" 2>&1; then
  printf 'Unexpected success without an authoring declaration\n' >&2
  exit 1
fi
grep -Fq 'declares no documentation.authoring.assign entries' "$temporary/result"

printf 'test-document-structure: ok\n'
