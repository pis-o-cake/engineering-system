---
type: adr
id: 0015
status: accepted
date: 2026-09-09
---

# 0015. 프로젝트가 복사한 hook 은 진단하고 덮어쓰지 않는다

`engsys hooks status` 가 프로젝트의 hook 사본과 현재 template 의 차이를 보고하고,
`engsys hooks update` 가 명시적으로 갱신한다. 사본이 근거한 template 과 기록 시점의 사본을 함께
기록해 "설치 직후"와 "프로젝트가 고쳐서 유지하는 것"을 구분한다.

## 결정

- `.engsys/hooks.txt` 에 hook 마다 두 해시를 기록한다. 사본이 근거한 template 의 해시와 기록 시점의
  사본 해시다. `init --hooks` 와 `hooks update` 가 이 기록을 남긴다.
- 상태는 다섯이다. `current`(사본 = template), `owned`(프로젝트가 고쳤고 현재 template 을 확인함),
  `outdated`(고치지 않았는데 template 이 바뀜), `modified`(고쳤고 그 뒤 template 이 바뀌었거나 기록이
  없음), `missing`.
- `hooks update` 는 `missing` 과 `outdated` 만 그대로 갱신한다. `modified` 는 `--force` 없이는
  바꾸지 않고 무엇이 다른지와 두 선택지를 출력한다.
- `--adopt` 는 사본을 그대로 두고 현재 template 을 확인한 것으로 기록한다. 이후 template 이 다시
  바뀔 때만 알린다.
- `doctor` 가 같은 상태를 보고한다. `upgrade` 는 hook 을 건드리지 않는다.

## 배경과 제약

`init --hooks` 가 심는 `pre-push` 와 `commit-msg` 는 프로젝트가 소유한다
([ADR 0008](0008-init-detects-declarations-and-seeds-the-project-gate.md)). 표준이 덮어쓰지 않는
것은 맞지만, 그 결과 template 을 고쳐도 이미 채택한 프로젝트가 그 변경을 알 방법이 없었다.

이 저장소에서 `pre-push` template 을 두 번 고쳤다. 전송 commit 판정([ADR
0013](0013-the-push-gate-judges-the-commit-it-sends.md))과 branch 이름 검사 호출이다. 두 변경 모두
`public-ai-qa` 에 도달하지 않았고, 도달하지 않았다는 사실도 드러나지 않았다.

제약은 소유권이다. 프로젝트가 고친 hook 을 표준이 조용히 되돌리면 그 프로젝트의 검사가 사라진다.
이 저장소의 `pre-push` 는 자기 test 전체를 돌리므로 template 으로 덮으면 gate 가 없어진다.

## 근거와 대안

- **`upgrade` 가 hook 도 갱신한다**: 한 명령으로 끝나지만 프로젝트가 고친 사본을 되돌린다. 실제로
  구현 중 이 저장소의 `pre-push` 를 덮어썼고 git 으로 복구했다. 소유권을 지키려면 갱신은 별도
  명령이어야 한다.
- **template 해시만 기록한다**: 처음 구현이 그랬다. 설치 직후와 프로젝트가 고친 뒤 유지하기로 한
  상태를 구분할 수 없어 사본을 고쳐도 `owned` 로 보고했다. 두 해시가 필요하다.
- **차이를 diff 로 출력한다**: hook 이 길면 출력이 화면을 덮는다. 실행할 `diff` 명령을 알려 주고
  판단은 사람이 한다.
- **template 에 version 을 적는다**: 사본이 그 줄만 고쳐도 어긋난다. 내용 해시가 정확하다.

## 영향

- 이미 채택한 프로젝트는 기록이 없어 처음에는 `modified` 로 보인다. `hooks update --adopt` 로
  현재 사본을 기준으로 잡거나 `--force` 로 template 을 받는다.
- `.engsys/hooks.txt` 가 계약 디렉토리에 하나 늘어난다. 프로젝트가 commit 한다.
- template 을 고치면 채택 프로젝트가 `doctor` 와 `hooks status` 에서 그 사실을 본다. 반영은 각
  프로젝트가 결정한다.
- `.claude/rules/engineering-system.md` 도 같은 성격의 사본이지만 이번 범위에 넣지 않았다.
