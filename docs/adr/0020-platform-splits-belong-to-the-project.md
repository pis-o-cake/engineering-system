---
type: adr
id: 0020
status: accepted
date: 2026-09-09
---

# 0020. platform 분기는 프로젝트가 선언한다

`commands.verify`와 `documentation.generated[].command`는 프로젝트가 선언한 문자열이다. 그 문자열이
OS마다 갈릴 때 무엇을 실행할지 정하는 주체를 정한다. 이 결정은
[ADR 0014](0014-projects-name-their-branches.md)의 선언 위치 원칙을 native command로 넓힌다.

## 결정

- 두 키 모두 `-macos`·`-linux`·`-windows` 접미사를 붙인 변형을 선언할 수 있다.
- 접미사 없는 기본 선언은 계속 필수다. 변형은 그 platform에서만 기본 선언을 대체한다.
- engsys가 `uname -s`로 platform을 판정한다. 사람이 고르는 플래그는 두지 않는다.
- 실행한 키를 출력에 찍는다 — `Running project verification (commands.verify-windows): ...`.
- 선언 목록에 없는 접미사는 `engsys check`가 거부한다.

## 배경과 제약

Python venv의 실행 파일은 macOS·Linux에서 `.venv/bin/`, Windows에서 `.venv/Scripts/`에 있다.
public-ai-qa의 `verify`는 `.venv/bin/poe`를 직접 가리켰고, Windows dev 서버에서
`No such file or directory`로 멈췄다. 계약이 한 머신의 경로를 정본으로 삼고 있었다.

이 분기는 언어의 문제이지 표준의 문제가 아니다. `npm test`·`go test ./...`·`cargo test`·
`./gradlew check`는 양쪽에서 같은 문자열이다. 표준이 platform별 명령을 알고 있으면 그 지식이
곧 낡으므로, 표준은 고르는 방법만 갖고 값은 프로젝트가 갖는다.

## 근거와 대안

`tests/test-platform-commands.sh`는 변형이 기본 선언을 대체하는지, 다른 platform의 변형을
고르지 않는지, 기본 선언 없는 record와 오타 난 접미사가 실패하는지 검사한다.

명령을 `poetry run poe check`처럼 이식 가능한 형태로 바꾸는 대안이 있다. 계약 한 줄로 끝나지만
프로젝트마다 그런 우회가 있는 것은 아니고, 없을 때 다시 이 기능을 만들게 된다.

접미사 대신 중첩 mapping(`verify: {default:, windows:}`)을 쓰는 대안은 이 저장소의 POSIX sh
파서를 한 단계 더 복잡하게 만든다. 접미사는 기존 한 줄 파서를 그대로 쓴다.

기본 선언을 선택 사항으로 두고 변형만 선언하게 하면, 선언하지 않은 platform에서 실행할 것이
없어진다. 그 경우 조용히 통과하는 대신 실패해야 하므로 기본 선언을 필수로 남긴다.

## 영향

기존 계약은 그대로 동작한다. 변형을 선언하지 않으면 판정 결과가 항상 기본 선언이다.

`commands` 아래 키 검사가 생기므로, 다른 이름의 명령을 그 블록에 넣어 둔 프로젝트는 `check`에서
거부된다. 현재 그런 프로젝트는 없다.

같은 revision을 실행한다는 것이 같은 dependency를 뜻하지는 않는다
([ADR 0019](0019-verification-fails-when-it-cannot-run.md)). platform 변형은 명령의 경로만
맞추며, 그 머신에 venv나 toolchain을 만드는 일은 여전히 프로젝트의 몫이다.
