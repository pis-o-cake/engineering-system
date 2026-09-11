#!/bin/sh

# tracker 항목의 본문 계약. 절 구성은 tracker 가 갖고 문체는 merge request 계약이 갖는다 —
# 같은 사람이 같은 변경을 설명하는 글이라 두 곳에서 갈리면 읽는 쪽이 먼저 안다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
contract="$system_root/packages/vcs-gov/tracker-contract.yaml"
commit_contract="$system_root/packages/vcs-gov/commit-contract.yaml"

expect() {
  grep -Fq "$1" "$contract" || { printf 'tracker contract is missing: %s\n' "$1" >&2; exit 1; }
}

# 본문은 세 절이 답한다. 등록하는 쪽이 양식을 새로 만들지 않게 계약이 절을 갖는다.
expect 'body:'
expect "heading: '목표'"
expect "heading: '핵심'"
expect "heading: '체크리스트'"

# 금지 문구는 복제하지 않고 가리킨다. 복제하면 한쪽만 고쳐진 채로 갈린다.
expect "shared-with: 'commit-contract.yaml#merge-request'"
expect "owned-by: 'commit-contract.yaml#merge-request.forbidden-body-contains'"

# 가리키는 대상이 실제로 있어야 한다. 끊어진 참조는 규칙이 없는 것과 같다.
grep -Fq 'forbidden-body-contains' "$commit_contract" || {
  printf 'merge-request.forbidden-body-contains is gone\n' >&2; exit 1
}

# 문체는 한 곳이 갖는다. 개조식 규칙은 merge request 계약에 있고 tracker 는 그것을 가리킨다.
grep -Fq '마침표를 찍지 않는다' "$commit_contract" || {
  printf 'merge-request.writing no longer fixes the terse style\n' >&2; exit 1
}
if grep -Fq '마침표를 찍지 않는다' "$contract"; then
  printf 'The tracker contract must not copy the style rules\n' >&2; exit 1
fi

# commit body 도 같은 문체다. 세 곳이 갈리면 읽는 사람이 먼저 안다.
grep -Fq 'body-writing' "$commit_contract" || {
  printf 'commit.body-writing is missing\n' >&2; exit 1
}

# 표와 체크리스트는 merge request 에 없는 자리라 tracker 가 갖는다.
expect '표로 보일 수 있으면 표로 쓴다'

# 상태와 종료 조건은 다른 값이다. 완료로 옮기려고 남은 조건을 지우는 것을 계약이 막는다.
expect '남은 종료 조건은 [ ] 로 남긴다'

# 핵심 제목은 확정한 사실이지 격언이 아니다. 항목 밖에서도 참인 문장은 제목 자리가 아니다.
expect '격언이나 일반론으로 쓰지 않는다'

printf 'ok tracker item bodies have sections here and borrow the writing rules\n'
