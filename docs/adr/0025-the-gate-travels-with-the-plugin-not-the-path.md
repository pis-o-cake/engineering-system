---
type: decision-record
id: 0025
status: accepted
date: 2026-09-10
---

# 0025. gate 는 PATH 가 아니라 plugin 에 실려 온다

merge request gate 를 프로젝트의 `.claude/settings.json` 이 아니라 plugin 의 hook catalog 가
등록한다. hook 은 `${CLAUDE_PLUGIN_ROOT}` 로 자기 자신을 찾고, 판정할 `engsys` 도 같은 곳에서
찾는다. PATH 는 마지막 후보다.

## 결정

- `packages/vcs-gov/package.yaml` 이 `PreToolUse` · `Bash` hook 을 선언하고, catalog 가 그것을
  `sh "${CLAUDE_PLUGIN_ROOT}/..."` 로 등록한다.
- hook 은 launcher 를 `ENGSYS_SYSTEM_ROOT` → `CLAUDE_PLUGIN_ROOT` → PATH 순으로 찾는다. 어디서도
  찾지 못하면 통과시키지 않고 그 사실을 돌려준다.
- 프로젝트의 `.claude/settings.json` 은 marketplace 와 plugin 선언만 갖는다. hook 항목은 뺀다.
- [ADR 0022](0022-a-declared-contract-needs-a-gate-not-an-instruction.md) 의 결정 중 gate 를
  등록하는 파일만 이 문서가 대신한다. "gate 를 부르는 것은 저장소에 든 선언이지 세션이 읽은
  skill 이 아니다" 는 그대로다 — 그 선언이 `enabledPlugins` 이고, plugin 이 gate 를 나른다.

## 배경과 제약

ADR 0022 는 gate 를 `.claude/settings.json` 의 hook 으로 등록했다. 명령은 `engsys vcs
merge-request-hook` 이었고, 이는 `engsys` 가 PATH 에 있다는 전제 위에 있었다.

2026-09-10 Windows 에서 그 전제가 깨졌다. Claude Code 가 hook 을 로그인 셸이 아닌 곳에서 부르고,
Git Bash 의 활성화 줄은 로그인 프로필에만 있다. 모든 Bash 호출마다 아래가 나왔다.

```
PreToolUse:Bash hook error
Failed with non-blocking status code: /usr/bin/bash: line 1: engsys: command not found
```

실패가 non-blocking 이라 명령은 그대로 실행됐다. 즉 **gate 가 꺼진 채로 돌았고**, 매 호출마다
오류만 찍혔다. [ADR 0019](0019-verification-fails-when-it-cannot-run.md) 가 정한 "실행하지 못한
검사는 실패" 가 hook 이 죽는 자리에서는 성립하지 않는다. 그 자리를 만들지 않는 것이 답이다.

제약은 경로다. `.claude/settings.json` 은 프로젝트가 commit 하므로 개발자 머신의 절대 경로를
쓸 수 없고, `${CLAUDE_PLUGIN_ROOT}` 는 plugin 이 등록한 hook 에만 주어진다. plugin 은 이미 그
파일이 선언해 붙는다([ADR 0023](0023-the-standard-ships-as-a-plugin-marketplace.md)).

## 근거와 대안

- **`engsys` 를 시스템 PATH 에 심는다**: Windows 에서 로그인 셸 밖의 PATH 까지 손대야 하고,
  `install.sh` 가 개발자의 shell profile 만 고친다는 [ADR 0007](0007-one-command-activation-and-main-as-release-channel.md)
  의 경계를 넘는다.
- **hook 명령을 `bash -lc` 로 감싼다**: 로그인 프로필을 읽게 되지만 셸 이름을 hook 이 갖게 되고,
  프로필이 무거운 개발자에게는 Bash 호출마다 그 비용이 붙는다.
- **settings.json 과 catalog 양쪽에 등록한다**: 어느 한쪽이 빠져도 돌지만, 둘 다 살아 있으면 같은
  본문을 두 번 판정하고 거부 메시지가 두 번 나온다.
- **hook 실패를 blocking 으로 만든다**: 이 저장소가 정할 수 있는 것이 아니다. Claude Code 가
  hook 오류를 non-blocking 으로 처리한다.

## 영향

- gate 는 plugin 이 붙은 세션에서 돈다. plugin 은 프로젝트가 commit 한 선언으로 붙으므로 세션을
  연 방법과는 여전히 무관하다.
- 이미 `.claude/settings.json` 에 hook 항목을 받은 프로젝트는 그 항목을 지운다. 남겨 두면 같은
  판정이 두 번 돌고 PATH 가 없는 머신에서는 오류가 계속 찍힌다.
- 표준 자체를 고치는 중이라면 `engsys claude` 가 lock revision 의 plugin 을 넘기므로 그 revision
  의 gate 가 돈다. 일상 경로에서는 marketplace 가 나르는 `main` 의 gate 가 돈다.
- `engsys` 를 어디서도 찾지 못하면 gate 는 거부한다. 그 상태는 `engsys doctor` 가 실패로 보고한다.
