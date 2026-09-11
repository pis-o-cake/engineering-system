---
type: verification-spec
status: active
version: 1
---

# 개발 환경 분리의 검증

표준이 붙었는지와 프로젝트가 자기 검사를 돌릴 수 있는지를 따로 판정한다. 전자는 외부 런타임 없이
반복 가능한 fixture로, 후자는 실제 프로젝트에서 한 번씩 확인한다. 두 결과를 한 줄로 합치지 않는다.

## 검증 범위

이 명세가 정하는 것은 `commands.environment-check`·`commands.environment-setup`을 둘러싼 상태
구분이다. 판정 대상은 표준의 설치·연결 완료, 프로젝트 환경 미준비, 환경 준비 실패, 프로젝트 검사
실패의 네 상태가 서로 다른 출력과 종료 코드로 나오는지다
([ADR 0026](../adr/0026-the-project-declares-how-its-environment-is-prepared.md)).

특정 패키지 관리자의 설치 성공은 범위가 아니다. `uv`·Poetry·npm·pnpm·Docker 중 무엇이 더 빠른지,
어떤 lockfile 전략이 맞는지도 판정하지 않는다. 그 선택은 프로젝트의 것이고, 표준이 보는 것은
선언한 명령의 종료 코드뿐이다.

## 시험 조건

설치 경로 검증과 통합 검증을 분리한다. 하나가 다른 하나의 실패에 가려지지 않게 하기 위해서다.

**설치 경로 (`tests/test-environment.sh`)** — `sh tests/test-all.sh`에 연결되며 모든 개발자의
`engsys verify`에서 돈다.

- fixture는 marker 파일 하나로 환경을 흉내 낸다. Python·Node 같은 외부 런타임과 네트워크를 쓰지
  않으므로, 표준의 설치 검증이 특정 언어의 설치 성공에 묶이지 않는다.
- 임시 Git 저장소에만 쓴다. 원본 저장소의 config와 HEAD는 `tests/test-all.sh`의 guard가 대조한다.
- 실제 패키지 관리자를 부르지 않는다. 준비 실패는 종료 코드 9를 내는 명령으로 흉내 낸다.

**통합 검증 (프로젝트별, 수동)** — 실제 프로젝트에서 채택하거나 계약을 고칠 때 한 번 실행한다.

- 대상 프로젝트의 clean clone에서 시작한다. 개발 환경이 없는 상태가 출발점이다.
- 선언한 `environment-setup`을 `engsys env prepare`로만 실행한다. 사람이 손으로 먼저 준비하면
  이 검증은 아무것도 확인하지 못한다.
- 네트워크와 설치 시간을 포함한다. 이 값은 설치 경로 검증의 기준에 섞지 않는다.
- OS마다 경로가 갈리는 프로젝트는 선언한 platform 변형의 수만큼 반복한다.

## 항목별 판정 기준

설치 경로는 네 상태가 모두 갈릴 때 통과다. 환경 미준비는 종료 코드 3이고 프로젝트의 native
명령이 실행되지 않는다. 준비 실패는 준비 명령의 종료 코드를 그대로 돌려주고 그 명령의 출력이
살아 있다. 검사 실패는 종료 코드 1이며 환경 문장을 쓰지 않는다. 선언이 없는 계약은 이 기능이
생기기 전과 같은 출력과 종료 코드를 낸다. 하나라도 어긋나면 실패로 남기고 구현을 고친다.

`verify`와 push gate가 `environment-setup`을 부르지 않는 것은 별도 항목이다. fixture의 marker
파일이 생기지 않았는지로 판정하며, 이 항목이 깨지면 다른 항목이 모두 통과해도 실패로 본다.

통합 검증은 clean clone에서 `engsys env prepare` 한 번으로 `engsys env status`가 통과하고, 이어진
`engsys verify`가 환경을 이유로 멈추지 않으면 통과다. 준비 후에도 `verify`가 환경 문제로 떨어지면
`environment-check`가 실제 필요 조건보다 느슨하게 선언된 것이므로 계약을 고친다.

설치 시간과 네트워크 사용량은 기록하되 판정 기준으로 쓰지 않는다. 프로젝트가 고를 수 있는 값이며,
표준이 그 값을 이유로 패키지 관리자를 강제하지 않는다.

## 실행과 증빙

```sh
sh tests/test-environment.sh          # 설치 경로 (외부 런타임 없이)
sh tests/test-all.sh                  # 이 저장소의 전체 검사에 포함된 상태로

engsys env status --project /path/to/project   # 통합 검증: 미준비 확인
engsys env prepare --project /path/to/project  # 선언한 준비 명령만 실행
engsys verify --project /path/to/project       # 준비 후 검증이 끝까지 도는지
```

설치 경로의 증빙은 `tests/test-all.sh`의 통과 기록이다. 통합 검증은 프로젝트 revision, OS,
실행한 명령과 각 단계의 종료 코드를 남긴다. 패키지 관리자의 상세 출력과 credential은 남기지 않는다.
