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

# 본문 스키마는 이 표준이 갖지 않는다. 도구 규약과 갈리면 같은 항목을 두 방식으로 쓰게 된다.
expect 'body:'
expect "owned-by: 'tracker tooling declared at vcs.tracker.provider'"
expect '인수 조건이다'
for heading in '목표' '핵심' '의존' '체크리스트' '버그 수정'; do
  if grep -Fq "heading: '$heading'" "$contract"; then
    printf 'The tracker contract must not fix a body schema: %s\n' "$heading" >&2; exit 1
  fi
done

# 금지 문구와 문체는 복제하지 않고 가리킨다.
expect "shared-with: 'commit-contract.yaml#merge-request'"
expect "owned-by: 'commit-contract.yaml#merge-request.forbidden-body-contains'"
grep -Fq '마침표를 찍지 않는다' "$commit_contract" || {
  printf 'merge-request.writing no longer fixes the terse style\n' >&2; exit 1
}
if grep -Fq '마침표를 찍지 않는다' "$contract"; then
  printf 'The tracker contract must not copy the style rules\n' >&2; exit 1
fi
grep -Fq 'body-writing' "$commit_contract" || {
  printf 'commit.body-writing is missing\n' >&2; exit 1
}

printf 'ok tracker item bodies have sections here and borrow the writing rules\n'
