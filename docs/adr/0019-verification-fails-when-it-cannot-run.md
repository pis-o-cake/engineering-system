---
type: adr
id: 0019
status: accepted
date: 2026-09-09
---

# 0019. 실행하지 못한 검사는 실패로 처리한다

push gate와 lock 기반 실행은 검사하지 않은 내용을 통과시키지 않는다. 이 결정은
[ADR 0013](0013-the-push-gate-judges-the-commit-it-sends.md)의 ref 생략과 checkout 대체 실행을
변경하고, [ADR 0012](0012-project-commands-run-at-the-locked-revision.md)의 실행 고정을 보완한다.

## 결정

- 배포용 pre-push는 `engsys`를 찾지 못하면 활성화 방법을 알리고 실패한다.
- 삭제를 제외한 모든 전송 ref에 `verify --revision`을 실행한다. 전송할 내용과 작업 트리가
  다르면 실패하며, 자기 레포용 hook도 같은 경로를 쓴다.
- lock과 checkout의 commit이 같아도 미커밋 수정이 있으면 clean한 locked worktree로 실행을 넘긴다.
- locked revision이나 clean cache를 준비하지 못하면 `--revision` 유무와 관계없이 실패한다.
  현재 checkout으로 대체하지 않는다.
- 자기 레포 검사와 명시적인 `ENGSYS_USE_CHECKOUT=1`은 개발용 예외다. 단위 테스트는 이 예외로
  현재 구현을 검사하고, 버전 고정 테스트는 예외를 끈 독립 Git fixture에서 실행한다.

## 배경과 제약

launcher가 없는 배포용 hook은 경고 후 exit 0이었다. HEAD가 아닌 ref의 native 검사도 생략했다.
자기 레포용 hook은 working tree의 테스트와 전송 commit의 문서 기록만 검사했다.
따라서 native 검사를 통과한 내용과 전송 내용이 다를 수 있었다.

실행 고정에도 예외가 있었다. 같은 commit이면 미커밋 검사를 사용했고, cache 준비 실패 시
일반 verify는 현재 checkout으로 실행됐다. 검사 결과에 표준 revision을 출력해도 그 revision의
코드를 실행했다는 보장은 없었다.

## 근거와 대안

`tests/test-pushed-commit.sh`는 전송 내용과 작업 트리가 다른 경우 두 hook이 실패하는지 검사한다.
`tests/test-init-detect.sh`는 launcher 부재를, `tests/test-pinned-execution.sh`는 같은 commit의
미커밋 수정 분리와 손상된 cache·없는 revision의 실패를 확인한다.

경고만 남기는 방식은 도구가 없는 환경에서 작업을 계속할 수 있지만 gate의 통과 의미가 달라진다.
임의 commit의 실행 환경을 새로 만드는 방식은 프로젝트의 dependency 설치까지 요구하므로
현재 범위에서는 작업 트리와 전송 내용의 일치를 먼저 확인한다.

## 영향

팀원은 launcher를 활성화하고 locked revision을 준비해야 push할 수 있다. 다른 내용을 가진
여러 ref는 각각 해당 내용을 checkout해 검사하고 push해야 한다. 이미 복사한 hook은
`engsys hooks update`로 갱신하며, 프로젝트가 수정한 사본은 직접 검토해야 한다.

이 변경은 로컬 hook의 우회나 프로젝트 native command의 환경 의존성을 제거하지 않는다.
서버의 필수 검사는 별도로 구성해야 한다. 같은 revision을 실행하는 것은 같은 dependency와
외부 상태까지 보장한다는 뜻이 아니다.
