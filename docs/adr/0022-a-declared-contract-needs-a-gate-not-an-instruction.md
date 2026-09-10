---
type: decision-record
id: 0022
status: accepted
date: 2026-09-10
superseded-in-part-by: 0025
---

# 0022. 선언한 규약에는 지시문이 아니라 gate 가 필요하다

merge request 본문을 `engsys vcs check-merge-request` 가 판정하고, 저장소에 든
`.claude/settings.json` 의 PreToolUse hook 이 `gh pr create` 앞에서 그것을 부른다. skill 은
쓰는 법을 알려 줄 뿐 강제하지 않는다.

## 결정

- `packages/vcs-gov/commit-contract.yaml` 의 `merge-request` 에 기계가 판정할 수 있는 값을
  분리한다. `section-heading-prefix` 와 `forbidden-body-contains` 다. 나머지 `writing` 과
  `excluded` 항목은 사람이 본다.
- `engsys vcs check-merge-request <file> [--title <text>]` 가 절 제목의 존재·순서, 선언 밖
  제목, 빈 절, 금지 문구를 판정한다. `--title` 은 commit 헤더 검사기를 그대로 쓴다.
- `engsys vcs merge-request-hook` 이 Claude Code PreToolUse 페이로드를 읽고 `gh pr create`
  와 `gh pr edit` 을 가로챈다. 본문은 `--body-file` 로 받는다. inline `--body` 와 본문 없는
  `gh pr create` 는 막는다. 읽지 못한 본문은 판정한 것이 아니다([ADR 0019](0019-verification-fails-when-it-cannot-run.md)).
- `init` 이 `.claude/settings.json` 을 프로젝트에 남긴다. gate 를 부르는 것은 이 파일이지
  세션이 읽은 skill 이 아니다.
- `vcs.merge-request` 를 선언하지 않은 프로젝트는 판정 대상이 아니다.

## 배경과 제약

`merge-request` 절은 [ADR 0011](0011-vcs-gov-owns-the-commit-and-merge-request-contract.md)
에서 `commit` 절과 같은 권위로 선언됐다. 그러나 `commit` 에는 `commit-msg` hook 과
`engsys vcs check-message` 가 있었고 `merge-request` 에는 판정하는 코드가 없었다. 규약을
지키게 하는 것은 `/engsys:write-merge-request` skill 하나였다.

2026-09-10 이 저장소의 PR #20 · #21 · #22 가 그 상태에서 열렸다. 세 본문 모두 선언 밖의 절
제목을 쓰고 `excluded` 가 금지한 자동 생성 서명으로 끝났다. 같은 기간 `public-ai-qa` 에서
연 merge request 는 규약을 지켰다. 차이는 사람이나 저장소가 아니라 세션을 연 방법이다 —
`engsys claude` 로 연 세션에는 skill 이 붙었고, 맨 `claude` 로 연 세션에는 붙지 않았다.

skill 은 중앙에 하나로 있다. 문제는 사본이 흩어지는 것이 아니라 전달 시점이다. 그리고 붙어
있었더라도 skill 은 지시문이라 따르지 않으면 아무 일도 일어나지 않는다. commit 메시지가
지켜지는 이유는 skill 이 있어서가 아니라 hook 이 막기 때문이다.

제약은 저장 위치다. merge request 본문은 git 안에 없다. commit 메시지처럼 git hook 으로
막을 지점이 없으므로, 본문이 만들어지는 지점에서 막아야 한다.

## 근거와 대안

- **skill 문구를 강하게 고친다**: 지시문의 강도를 올릴 뿐이다. 세션이 그것을 읽지 않으면
  강도는 의미가 없다.
- **plugin hook catalog 에만 등록한다**: `engsys claude` 로 연 세션에서만 돈다. 지금 문제를
  그대로 남긴다. 저장소에 든 설정이라야 세션을 연 방법과 무관해진다.
- **명령 문자열에서 `gh` 를 문자열로 찾는다**: 처음 구현이 그랬고, 이 gate 를 설명하는 커밋
  메시지가 자기 자신에게 걸렸다. 본문에 `gh pr create` 라는 글자가 있었을 뿐이다. 지금은
  heredoc 본문을 걷어내고 명령 자리에 있는 `gh` 만 본다.
- **inline `--body` 도 파싱해 판정한다**: shell 인용을 되돌려야 하고 heredoc 은 페이로드에서
  경계를 알 수 없다. 판정하지 못하는 형태를 허용하면 그 형태로 우회한다. 파일을 요구하면
  본문이 diff 되고 재검토도 쉬워진다.
- **CI 에서 PR 본문을 검사한다**: 서버 검사가 생기면 두 번째 방어선으로 맞다. 지금 이
  저장소에는 서버 CI 가 없고, 본문이 잘못 열린 뒤에 아는 것보다 열리기 전에 막는 편이 낫다.

## 영향

- `gh pr create` 는 `--body-file` 을 요구한다. 본문을 파일로 쓰는 절차가 하나 늘고, 그
  파일이 검토 대상으로 남는다.
- Claude Code 를 쓰지 않는 사람은 이 gate 를 거치지 않는다. 판정은 `engsys vcs
  check-merge-request` 로 직접 부를 수 있고, 서버 검사가 생기면 같은 명령을 쓴다.
- 이미 채택한 프로젝트는 `.claude/settings.json` 이 없다. `init` 을 다시 돌리거나 template
  에서 복사한다. 이 파일은 프로젝트가 소유하며 표준이 덮지 않는다.
- 판정 범위는 절 제목·순서·빈 절·금지 문구·title 형식이다. `writing` 의 문체와 중복 서술은
  기계가 판정하지 않으므로 리뷰어가 계속 본다.
