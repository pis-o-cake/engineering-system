---
type: adr
id: 0008
status: accepted
date: 2026-09-08
---

# 0008. init이 선언을 감지하고 프로젝트 push gate를 seed한다

`engsys init --detect`가 native 검증 명령, source-of-truth, 문서 정본 경로, lifecycle을 프로젝트에서
읽어 채운다. `--hooks`는 프로젝트가 소유할 `pre-push` gate를 seed한다. 문서 골격은 만들지 않는다.

## 결정

- `init --detect`는 **설정하지 않은 선언만** 채운다. 명시한 옵션이 언제나 이긴다. 채운 값은 모두
  화면에 출력한다.
- 감지하지 못한 native 검증 명령은 기본값을 만들지 않고 `--verify`를 요구한다. 틀린 명령을 넣으면
  첫 `engsys verify`가 실패하고, 그 실패의 원인이 표준으로 보인다.
- 문서 유형 배정은 **아직 문서가 없는 경로에만** 쓴다. 이미 문서가 있는 경로는 배정하지 않고 그
  경로를 출력한다. 유형을 선언하지 않은 문서를 배정하면 채택 직후 모든 검사가 실패한다.
- `--hooks`는 `templates/project/.githooks/pre-push`를 프로젝트에 복사하고 `core.hooksPath`가
  비어 있을 때만 등록한다. 기존 hook 파일과 기존 `core.hooksPath`는 바꾸지 않는다.
- 그 gate는 `engsys`를 PATH에서 찾지 못하면 push를 막지 않고 그 사실을 출력한다.
- 문서 골격 template은 만들지 않는다.

## 배경과 제약

`init`은 `--verify`, `--source`, `--generated`, `--lifecycle`을 모두 손으로 받았다. 새 프로젝트마다
같은 값을 다시 타이핑해야 했고, 무엇을 선언할 수 있는지는 `--help`를 읽어야 알 수 있었다.

프로젝트의 push gate도 매번 새로 썼다. `public-ai-qa`는 `engsys verify`와 전송할 commit의 검토
검사를 부르는 hook을 직접 작성했다. 같은 파일을 프로젝트마다 다시 만들면 조금씩 갈라진다.

제약은 두 가지다. 표준은 프로젝트에 공통 정책을 복사하지 않는다. 그리고
[ADR 0006](0006-document-type-contract-in-posix-sh.md)의 구조 검사는 배정된 문서에 유형 선언을
요구하므로, 배정을 자동으로 넓히면 채택 첫날 검사가 전부 실패한다.

## 근거와 대안

- **문서 골격 template을 만든다**: `docs/README.md`, `docs/architecture/README.md`, ADR 목록을 미리
  넣어 주는 안이다. 그러나 유형 계약은 필수 절에 독자가 필요한 내용을 요구한다. 빈 절을 채운
  골격은 그 계약이 금지하는 상태를 기본값으로 만든다. 문서는 필요할 때 `write-document`로 만든다.
- **기존 문서를 자동으로 배정한다**: 배정 자체는 정확하다. 그러나 그 문서들에는 유형 선언이 없어
  `engsys docs check`가 즉시 전부 실패한다. 채택 직후의 실패는 표준을 끄는 이유가 된다.
- **감지한 검증 명령이 없으면 `true`를 넣는다**: `verify`가 항상 통과하게 되어 gate가 장식이 된다.
- **profile을 언어별로 나눈다**: `python`, `android` profile을 추가하는 안을 검토했다. profile은
  package 조합을 선언하는데 지금 package는 셋뿐이고 baseline이 전부를 포함한다. 같은 조합에 이름만
  다른 profile은 선택지를 늘리고 아무 차이도 만들지 않는다. 언어에 따라 실제로 달라지는 package가
  생기면 그때 나눈다.
- **gate가 `engsys`를 못 찾으면 push를 막는다**: 활성화하지 않은 팀원의 push가 전부 막힌다. 막힌
  이유를 설명하지 못하는 gate는 고쳐지지 않고 삭제된다. 대신 그 사실을 출력하고 통과시킨다.

## 영향

- 새 프로젝트의 채택은 `engsys init --detect --hooks` 한 줄이다. 감지 결과는 출력되며 계약 파일에서
  다시 확인할 수 있다.
- 감지는 최상위 디렉토리만 본다. `backend/pyproject.toml`처럼 한 단계 아래에 있는 스택은 찾지
  못하므로 `--verify`로 직접 준다.
- 이미 문서가 있는 프로젝트는 배정을 손으로 넓힌다. 문서를 유형에 맞게 고친 뒤 `assign`에 추가하는
  순서다.
- 프로젝트가 복사한 `pre-push`는 그 프로젝트가 소유한다. 표준이 나중에 그 파일을 덮어쓰지 않는다.
  gate를 고쳐야 하면 각 프로젝트에서 고친다.
