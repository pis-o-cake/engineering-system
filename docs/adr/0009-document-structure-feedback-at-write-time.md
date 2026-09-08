---
type: adr
id: 0009
status: accepted
date: 2026-09-08
---

# 0009. 문서 구조 검사를 작성 시점으로 옮기고 결과를 Claude에게 돌려준다

문서를 쓴 직후 그 문서 하나만 구조 검사하고, 실패를 세션 안의 Claude에게 돌려준다. 검토 기록
검사는 옮기지 않고 push gate에 남긴다. 턴마다 전체를 검증하는 `Stop` hook은 계속 쓰지 않는다.

## 결정

- `PostToolUse` hook이 방금 쓴 Markdown·HTML 하나를 `engsys docs check --path`로 검사한다.
  실패하면 exit 2로 끝내 stderr가 Claude에게 전달되고, Claude가 그 자리에서 고친다.
- `engsys docs check --path <document>`는 배정되지 않은 경로, 없는 파일, `authoring` 선언이 없는
  프로젝트에서 오류 없이 끝난다. 모든 쓰기에서 도는 hook이 소음을 내지 않기 위해서다.
- `SessionStart` hook이 남은 구조 findings와 미검토 문서 수를 한 줄로 주입한다. 아무것도 막지
  않으며, 남은 문제가 없으면 아무것도 출력하지 않는다.
- 편집 검토 기록 검사는 작성 시점으로 옮기지 않는다. `engsys verify`와 push gate에 남는다.
- `Stop` hook과 `UserPromptSubmit` classifier는 계속 쓰지 않는다.

## 배경과 제약

v0.1은 모든 검사를 push gate에 뒀다. 그래서 문서를 열 편 쓰고 push하면 그때 열 편의 문제가
한꺼번에 나온다. 어느 편집이 무엇을 깼는지는 그 시점에 이미 흐려져 있다.

[design 0001](../design/0001-foundation.md)의 context budget은 `Stop` 자동 검증과
`UserPromptSubmit` classifier를 non-goal로 뒀다. 매 턴 context와 마찰을 늘리기 때문이다. 같은
문서가 hook의 범위도 정했다 — hook은 판단이 필요 없는 것만 한다.

## 근거와 대안

- **`Stop` hook에서 `engsys verify`를 돌린다**: 결정적이지만 턴마다 native test까지 돌아 수십 초가
  걸리고, 사용자가 그동안 기다린다. 실패해도 어느 편집이 원인인지 알려 주지 않는다. non-goal을
  유지할 이유가 그대로 남는다.
- **route rule에 "변경 후 verify를 돌린다"를 적는다**: 비용이 없지만 보장도 없다. 모델이 그 문장을
  따를 때만 돈다.
- **파일 하나를 쓴 직후 검사한다**: 필수 절이 있는지 없는지는 판단이 아니므로 hook의 범위에
  들어간다. 비용은 단일 파일이고, 원인은 방금 쓴 그 파일이며, 결과가 Claude에게 가므로 사용자가
  개입하지 않는다. 이것을 택했다.
- **검토 기록도 작성 시점에 요구한다**: 작성 중간마다 "검토 안 됨"이 뜬다. 검토는 완료의 개념이라
  중간 상태에서 요구하면 소음이 된다. push gate에 남긴다.

## 영향

- `PostToolUse`는 쓰기 뒤에 돌므로 막지 못하고 고치게 한다. 사람이 에디터로 직접 문서를 고치면 이
  층은 걸리지 않으며, 그 경우는 push gate가 잡는다.
- 세션 시작마다 `docs check`와 `review check`가 한 번씩 돈다. 문서가 많은 프로젝트에서 느려지면
  timeout 20초에서 잘리고, 잘려도 세션은 그대로 시작된다.
- hook이 셋이 되면서 matcher 없는 event를 plugin manifest 생성이 지원해야 했다. `SessionStart`는
  matcher를 갖지 않는다.
- 이 층은 구조만 본다. 문장과 근거의 적절성은 여전히
  [ADR 0005](0005-individual-document-editorial-review.md)의 개별 편집 검토가 판정한다.
