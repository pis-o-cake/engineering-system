#!/bin/sh

# 표준은 언제 등록하고 무엇을 반드시 적고 무엇으로 닫는지를 갖는다. 어느 도구에 어떤 권한으로
# 쓸지는 프로젝트가 선언한다. 표준은 tracker 이름도 label 이름도 갖지 않는다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0
project="$temporary/project"
mkdir -p "$project"
git -C "$project" init -q
"$system_root/bin/engsys" init --project "$project" --verify true >/dev/null 2>&1

engsys() { "$system_root/bin/engsys" "$@" --project "$project" \
  >"$temporary/out" 2>"$temporary/err"; }
fail() { printf '%s\n' "$1" >&2; cat "$temporary/out" "$temporary/err" >&2; exit 1; }

# 선언이 없으면 도구는 답하지 않는다. 기본값을 두면 선언을 빠뜨린 프로젝트가 남의 tracker 를
# 물려받는다.
engsys vcs tracker
[ ! -s "$temporary/out" ] || fail 'a project without a tracker declaration must print nothing'
engsys vcs check-tracker
[ ! -s "$temporary/out" ] || fail 'a project without a tracker declaration is not checked'

cat >>"$project/.engsys/project.yaml" <<'EOF'

vcs:
  commit:
    subject-ending: 'noun'
  merge-request:
    target: 'main'
  tracker:
    provider: 'gitlab'
    project: 'group/thing'
    labels:
      defect: '결함'
      decision: '결정'
    agent:
      create: 'allowed'
      close: 'ask'
EOF
python3 "$system_root/tools/validate-contract.py" project "$project/.engsys/project.yaml" >/dev/null

# 선언한 값을 그대로 답한다.
engsys vcs tracker || fail 'tracker must resolve a declared block'
grep -q "^provider	gitlab$" "$temporary/out" || fail 'provider was not resolved'
grep -q "^project	group/thing$" "$temporary/out" || fail 'tracker project was not resolved'
grep -q "^label	defect	결함$" "$temporary/out" || fail 'label mapping was not resolved'

# 선언하지 않은 담당자를 지어내지 않는다.
grep -q "^default-assignee	미정$" "$temporary/out" || fail 'an undeclared assignee must stay 미정'

# 선언하지 않은 권한은 계약의 기본값을 따른다. create 는 프로젝트가 allowed 로 열었다.
grep -q "^agent	create	allowed$" "$temporary/out" || fail 'a declared permission must win'
grep -q "^agent	comment	ask$" "$temporary/out" || fail 'an undeclared permission must fall back to the contract'
grep -q "^agent	accept-risk	ask$" "$temporary/out" || fail 'accept-risk must default to ask'

engsys vcs check-tracker || fail 'a valid declaration must pass'

# 사람이 판단할 것을 프로젝트가 열 수 없다.
cp "$project/.engsys/project.yaml" "$temporary/contract"
sed "s/      close: 'ask'/      close: 'ask'\n      accept-risk: 'allowed'/" "$temporary/contract" \
  >"$project/.engsys/project.yaml"
if engsys vcs check-tracker; then
  fail 'accept-risk must not be delegated to the agent'
fi
grep -Fq '사람이 판단한다' "$temporary/err" || fail 'the refusal did not name the reason'
cp "$temporary/contract" "$project/.engsys/project.yaml"

# provider 는 선언한 것 중에서만 고른다.
sed "s/    provider: 'gitlab'/    provider: 'jira'/" "$temporary/contract" \
  >"$project/.engsys/project.yaml"
if engsys vcs check-tracker; then
  fail 'an unsupported provider must be refused'
fi
grep -Fq '지원하지 않는 provider' "$temporary/err" || fail 'the refusal did not name the provider'
cp "$temporary/contract" "$project/.engsys/project.yaml"

# --- merge request 본문의 누락 확인 ---
body="$temporary/body.md"
check() { "$system_root/bin/engsys" vcs check-merge-request "$body" --project "$project" \
  >"$temporary/out" 2>"$temporary/err"; }
write_body() {
  cat >"$body" <<EOF
## 요약

한 문장이다.

## 변경 사항

- 하나를 바꾼다

## 검증

- 돌렸다

## 영향 및 후속 작업

$1
EOF
}

# 남은 것이 없다고 쓰는 본문은 대상이 아니다.
write_body '없음'
check || fail 'a body without unresolved work must pass'

# 후속 작업을 적었는데 어디서 추적하는지 없으면 그 항목은 이 본문에서만 산다.
write_body '- 후속 작업이 하나 남았다.'
if check; then
  fail 'unresolved work without a tracked item must be refused'
fi
grep -Fq '추적할 항목 링크가 없다' "$temporary/err" || fail 'the refusal did not name the reason'

# 링크가 있으면 통과한다. 표준은 링크의 형식만 보고 항목의 내용은 보지 않는다.
write_body '- 후속 작업은 group/thing/-/issues/12 에서 추적한다.'
check || fail 'unresolved work with a tracked item must pass'

printf 'ok unresolved items are declared by the project and linked by the standard\n'
