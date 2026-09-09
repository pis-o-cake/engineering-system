---
type: adr
id: 0010
status: accepted
date: 2026-09-09
---

# 0010. SessionStart는 검토 backlog만 세고 구조는 다시 검사하지 않는다

세션 시작 hook에서 전체 구조 검사를 뺀다. 검토 기록이 없는 문서 수만 세고, launcher를 부르지
않는다. 실측 7.2초가 0.16초가 된다.
[ADR 0009](0009-document-structure-feedback-at-write-time.md)의 SessionStart 결정을 대체한다.

## 결정

- `SessionStart` hook은 계약의 `documentation.review.scopes` 안에서 **검토 기록 파일이 없는 문서
  수**만 센다. 구조 findings는 세지 않는다.
- hook은 `engsys`를 실행하지 않는다. 계약과 파일 존재만 읽으므로 `CLAUDE_PLUGIN_ROOT` 없이도
  동작한다.
- 선언한 scope 전체를 `git ls-files`에 한 번에 넘긴다. scope마다 git을 띄우면 선언이 늘어난 만큼
  느려진다.
- hook timeout을 20초에서 5초로 내린다.

## 배경과 제약

ADR 0009는 `SessionStart`가 `docs check`와 `review check`를 각각 한 번씩 돌게 했다. 그 문서의
영향 절은 "문서가 많은 프로젝트에서 느려지면 timeout에서 잘린다"를 미확정으로 남겼다.

`public-ai-qa`(배정 문서 77편, `review.scopes` 77)에서 실측했다.

| 항목 | 실측 |
|---|---|
| `docs check` 전건 | 5.1초 |
| `review check` 전건 | 2.2초 |
| `SessionStart` 합계 | **7.2초, 출력 없음** |

그 저장소는 findings 0·pending 0이라 hook이 정상적으로 침묵했다. 즉 깨끗한 저장소에서 세션마다
7.2초를 쓰고 아무것도 말하지 않는다. timeout에는 걸리지 않았으므로 남은 문제는 비용 대비 값이다.

비용의 대부분은 `docs check`다. 문서마다 awk를 여러 번 띄운다.

## 근거와 대안

- **구조 검사를 SessionStart에서 뺀다**: 구조는 `PostToolUse`가 작성 시점에 그 문서만 정확히 보고
  (0.145초), 나머지는 push gate가 본다. `SessionStart`의 고유한 값은 이 세션이 만들지 않은 검토
  backlog다. 그것만 남긴다.
- **구조를 싸게 근사한다**: frontmatter만 훑어 `type` 누락을 세는 안이다. 유형 계약을 두 곳에서
  해석하게 되어, 안내와 검사가 서로 다른 필수 구성을 갖는 상태를 만든다.
  [design 0002](../design/0002-document-authoring-contracts.md)가 금지한 상태다.
- **검토 기록도 본문 해시로 대조한다**: 정확하지만 세션마다 전 문서를 다시 해시한다. 파일 존재만
  보면 0.16초이고, 놓치는 것은 "검토 후 본문이 바뀐 문서" 하나다. 그것은 대개 세션 중에 생기고
  `engsys review check`와 push gate가 잡는다.
- **SessionStart를 없앤다**: backlog를 알려 주는 층이 사라진다. 0.16초면 유지할 값이 있다.
- **`docs check` 자체를 최적화한다**: 문서마다 awk를 띄우는 구조를 고치면 이 hook도 함께 싸진다.
  검사기 전체를 다시 쓰는 변경이라 이번에 하지 않았다. push gate와 `verify`에서 5.1초는 backend
  검사에 묻히므로 지금 급하지 않다.

## 영향

- `public-ai-qa` 기준 7.2초에서 0.16초가 됐다. 같은 저장소, 같은 선언에서 잰 값이다.
- `SessionStart`는 `documentation.review.scopes`를 선언한 프로젝트에서만 말한다. 선언이 없으면
  아무것도 출력하지 않는다.
- 검토 후 본문이 바뀐 문서는 이 hook이 세지 않는다. 그 상태는 `engsys verify`와 push gate가 잡는다.
- ADR 0009의 다른 결정 — `PostToolUse`의 작성 시점 구조 검사, 검토 기록 검사를 옮기지 않는 것,
  `Stop` hook을 쓰지 않는 것 — 은 그대로 유효하다.
