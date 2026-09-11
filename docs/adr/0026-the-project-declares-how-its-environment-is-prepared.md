---
type: adr
id: 0026
status: accepted
date: 2026-09-11
---

# 0026. 개발 환경은 프로젝트가 선언하고 표준은 실행만 한다

표준의 설치·연결과 프로젝트 개발 환경의 준비를 분리한다. 프로젝트가 진단·준비 명령을 선언하고
engsys는 그 명령의 실행과 판정만 맡는다. 이 결정은
[ADR 0020](0020-platform-splits-belong-to-the-project.md)이 명령의 경로만 맞추고 남겨 둔 부분을
채우며, [ADR 0019](0019-verification-fails-when-it-cannot-run.md)의 "실행하지 못한 검사는 실패"를
환경 미준비까지 넓힌다.

## 결정

- `commands.environment-check`와 `commands.environment-setup`을 선언할 수 있다. 둘 다 선택이며,
  `-macos`·`-linux`·`-windows` 변형은 `verify`와 같은 규칙으로 고른다.
- `environment-check`는 상태만 판정한다. exit 0이면 프로젝트가 자기 검사를 돌릴 수 있는 상태다.
- `environment-setup`은 환경을 준비한다. `engsys env prepare`와 `engsys setup`의 동의 단계에서만
  실행된다. `verify`·`check`·Git hook은 이 명령을 부르지 않는다.
- `engsys env status`와 `engsys env prepare`를 둔다. 준비 명령을 부르는 자리는 사람이 그것을
  요청한 흐름뿐이라는 사실을 명령 이름으로 드러낸다.
- 환경 미준비는 종료 코드 `3`이다. 통과(0)와도 검사 실패(1)와도 다르다. `verify`는 이 상태에서
  프로젝트의 native 명령을 시작하지 않고 끝내므로, push gate는 계속 막는다.
- `doctor`는 표준의 설치·연결 문제와 프로젝트 환경을 다른 칸에 센다. `problem(s) to fix`는 전자만
  세고, 환경은 `ENV` 줄과 `environment step(s)`로 따로 보고하며 종료 코드 `3`으로 끝난다.
- 표준은 언어별 설치 로직을 갖지 않는다. `uv`·Poetry·npm·pnpm·Docker·자체 스크립트 중 무엇을 쓸지는
  프로젝트가 정하고, `init --detect`는 이 두 명령을 추측하지 않는다.

## 배경과 제약

채택 검증이 대상 프로젝트의 venv에서 반복해서 멈췄다. `engsys verify`가 `commands.verify`를
실행하면 그 명령은 프로젝트의 개발 환경을 쓰는데, 환경이 없으면 shell이 실행 파일을 찾지 못한
채로 끝난다. 그 실패는 `engsys setup`의 마지막 단계에서 나므로 표준의 설치 실패로 읽혔다.

표준이 붙지 않은 것, 프로젝트 환경이 없는 것, 프로젝트 검사가 떨어진 것은 세 가지 다른 상태이고
고치는 사람도 방법도 다르다. 그런데 셋 모두 `engsys setup` 과 `engsys verify` 의 같은 자리에서
같은 모양으로 끝났다.

제약은 두 가지다. 표준은 언어를 알지 못하고, 알게 되면 그 지식이 곧 낡는다
([ADR 0020](0020-platform-splits-belong-to-the-project.md)). 그리고 설치를 자동으로 실행하는
gate는 push 한 번에 네트워크와 디스크를 쓰고 프로젝트 파일을 바꾼다. 사람이 요청하지 않은 자리에서
일어날 일이 아니다.

## 근거와 대안

`tests/test-environment.sh`는 marker 파일 하나로 환경을 흉내 내는 fixture로 세 상태가 갈리는지,
`verify`와 hook이 준비 명령을 부르지 않는지, 선언이 없는 기존 계약이 그대로 도는지 검사한다.
외부 런타임이 없어도 돌므로 설치 경로의 검증이 특정 언어의 설치 성공에 묶이지 않는다. 실제
프로젝트의 준비와 test 실행은 이 검사의 범위가 아니며 별도 통합 검증이 맡는다
([docs/verification/environment.md](../verification/environment.md)).

- **표준이 venv·node_modules를 직접 만든다**: 채택 첫날은 편하다. 그러나 패키지 관리자마다 절차가
  다르고, 표준이 그 목록을 갖는 순간 프로젝트가 관리자를 바꿀 때마다 표준을 고쳐야 한다.
- **`verify` 실패 메시지에 안내만 덧붙인다**: 코드 한 줄이면 끝나지만 종료 코드가 같아 기계는
  여전히 구분하지 못한다. gate와 CI가 두 상태를 같게 다룬다.
- **환경 미준비를 통과로 처리한다**: 채택이 빨리 끝나 보이지만 검사하지 않은 것을 통과시킨다.
  [ADR 0019](0019-verification-fails-when-it-cannot-run.md)가 이미 거절한 방식이다.
- **`environment-check`를 필수로 만든다**: 상태를 언제나 판정할 수 있지만 기존 계약이 전부
  깨진다. 선언이 없으면 판정하지 않고 그 사실을 알린다.
- **준비 명령 없이 진단 명령만 선언한다**: 허용한다. 이 저장소가 그렇다. python3 설치는 표준도
  프로젝트도 대신할 수 없으므로 상태만 알리고 사람에게 넘긴다.

## 영향

기존 계약은 그대로 동작한다. 두 키를 선언하지 않으면 `verify`의 실행 경로가 이전과 같다.

`engsys setup`은 일곱 단계에서 열 단계가 된다. `검사` 뒤에 `프로젝트 개발 환경`과 `검증`이
들어가며, 환경이 준비되지 않으면 `verify`를 돌리지 않고 그 사실을 표준의 실패와 구분해 보고한다.
[ADR 0018](0018-adoption-is-a-guided-sequence.md)의 단계 구성이 이 범위에서 바뀐다.

배포용 `pre-push` template이 종료 코드 `3`을 따로 다룬다. 이미 복사한 hook은
`engsys hooks update`로 갱신해야 이 문장을 받는다. 갱신하지 않아도 push는 계속 막힌다. 갈라지는
것은 안내문이지 합격 여부가 아니다.

환경이 준비됐다는 판정은 그 환경이 옳다는 뜻이 아니다. `environment-check`가 무엇을 보는지는
프로젝트가 정하며, 느슨하게 선언하면 `verify`가 여전히 환경 문제로 떨어진다.
