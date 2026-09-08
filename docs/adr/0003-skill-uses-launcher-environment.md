---
type: adr
id: 0003
status: accepted
date: 2026-09-07
---

# 0003. skill은 launcher가 export한 ENGSYS_PLUGIN_ROOT만 사용한다

plugin 안의 스크립트를 실행하는 skill은 launcher가 export한 `ENGSYS_PLUGIN_ROOT`만 사용한다.
`CLAUDE_PLUGIN_ROOT`는 hook process 전용이라 skill에서는 비어 있다.

## 맥락

v0.1의 skill 5개는 모두 `${CLAUDE_PLUGIN_ROOT}/bin/engsys` 형태로 명령을 실행하도록 적혀
있었다. 실제로 `CLAUDE_PLUGIN_ROOT`와 `CLAUDE_PROJECT_DIR`은 Claude Code가 **hook process에만**
주입하는 변수다. skill 본문의 지시에 따라 Bash로 실행하면 이 변수는 비어 있고, 명령은
`/bin/engsys`를 실행하려다 실패한다.

즉 skill 전체가 동작하지 않는 상태였고, 문서상으로는 맞아 보였기 때문에 발견이 늦었다.

## 결정

- plugin 안의 스크립트를 실행해야 하는 skill은 `ENGSYS_PLUGIN_ROOT`를 쓴다.
- 이 변수는 `engsys claude` launcher가 plugin view를 만든 뒤 export한다. launcher는 함께
  프로젝트 root로 이동해서 Claude Code를 실행하므로, skill은 프로젝트 파일을 상대 경로로 읽는다.
- `CLAUDE_PLUGIN_ROOT`는 hook 명령에서만 쓴다. hook은 Claude Code가 직접 실행하므로 이 변수가
  주입된다.
- skill 본문에 hook 전용 변수가 다시 등장하면 `tests/test-launcher.sh`가 실패한다.

## 대안

- **skill이 plugin 경로를 직접 찾는다**: 경로 추론 로직이 skill 본문마다 중복되고, lock에 따라
  달라지는 plugin view를 skill이 알아야 한다.
- **`engsys`를 PATH에 넣고 그냥 `engsys`로 호출한다**: 짧지만 어떤 revision의 engsys가
  실행되는지 세션마다 달라진다. lock으로 revision을 고정한다는 설계와 충돌한다.

## 결과

- skill은 `engsys claude`로 시작한 세션에서만 정상 동작한다. 변수가 비어 있으면 skill이
  그 사실을 말하고 멈춘다.
- Claude Code가 skill 실행 환경에 plugin 경로를 노출하게 되면 이 결정을 다시 검토한다.
