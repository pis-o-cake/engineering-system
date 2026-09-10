---
type: decision-record
id: 0023
status: accepted
date: 2026-09-10
---

# 0023. 표준은 plugin marketplace 로 배포한다

프로젝트가 `.claude/settings.json` 에 marketplace 와 plugin 을 선언하고, 그 파일을 commit 한다.
Claude Code 를 어떻게 열든 — CLI 든 데스크톱 앱이든 IDE 확장이든 — skill 과 hook 이 붙는다.
`engsys claude` 는 lock revision 의 skill 까지 맞춰야 할 때 쓰는 엄격한 경로로 남는다.

## 결정

- 표준 저장소에 `.claude-plugin/marketplace.json` 을 둔다. 이 저장소가 곧 marketplace 다.
- `engsys init` 이 프로젝트의 `.claude/settings.json` 에 `extraKnownMarketplaces` 와
  `enabledPlugins` 를 쓴다. 좌표는 표준 checkout 의 `origin` 에서 얻는다. GitHub origin 이
  아니면 hook 만 쓰고 무엇을 직접 적어야 하는지 알린다.
- 이 파일은 프로젝트가 소유한다. 이미 있으면 덮지 않는다.
- `engsys claude` 는 재현 모드로 남는다. lock revision 의 skill·hook 까지 그 revision 의 것으로
  맞춰야 할 때 쓴다 — 옛 lock 에 묶인 프로젝트를 그때의 안내로 다시 보거나, 표준 자체를 고치는
  중일 때다. 일상 작업의 기본 경로가 아니다.
- `doctor` 가 프로젝트에 이 선언이 있는지, 그리고 그 선언이 기대는 `engsys` 가 PATH 에 있는지
  함께 보고한다.
- [ADR 0007](0007-one-command-activation-and-main-as-release-channel.md) 이 「근거와 대안」에서
  거절한 marketplace 배포를 이 문서가 뒤집는다. 그 문서의 나머지 결정 — `install.sh` 하나로 하는
  개발자 활성화, `doctor` 의 진단 범위, `origin/main` 이라는 배포 채널 — 은 그대로다.

## 배경과 제약

skill 과 hook 은 표준 저장소 한 곳에 있고 사본이 흩어지지 않는다. 문제는 전달 시점이었다.
`engsys claude` 가 `--plugin-dir` 로 넘길 때만 세션에 붙었고, 그래서 세션을 연 방법에 따라
같은 저장소에서 다른 결과가 나왔다([ADR 0022](0022-a-declared-contract-needs-a-gate-not-an-instruction.md)).

데스크톱 앱과 IDE 확장에는 `engsys claude` 에 해당하는 진입점이 없다. 그 사용자에게는 표준을
붙일 방법이 아예 없었다.

ADR 0007 은 이 방식을 검토하고 거절했다. 이유는 "marketplace 는 plugin 버전을 개발자 단위로
고정하고, 이 시스템은 프로젝트 단위로 고정한다. 두 고정 축이 충돌한다"였다. 그 판단은 plugin 이
판정 코드를 나른다는 전제 위에 있었다. 실제 구조는 그렇지 않다 — plugin 은 skill 과 hook 배선을
나르고, 판정은 hook 이 부르는 `engsys` 가 lock revision 에서 한다. 충돌하는 축은 하나뿐이고
그것은 안내문이다.

제약은 [ADR 0012](0012-project-commands-run-at-the-locked-revision.md) 가 정한 고정 실행이다.
marketplace 는 브랜치를 따라가므로 skill 과 hook 배선은 `main` 에서 온다. 그러나 판정은 여전히
고정된다 — hook 이 하는 일은 `engsys` 를 부르는 것이고, `engsys` 는 자기를 lock revision 으로
다시 실행한다. 흔들리는 것은 안내문이지 합격 여부가 아니다.

## 근거와 대안

- **프로젝트마다 `.claude/skills/` 에 skill 을 복사한다**: 세션과 무관해지지만 사본이 프로젝트
  수만큼 늘어난다. 표준을 고쳐도 각 프로젝트가 따로 받아야 한다.
- **`engsys claude` 만 유지한다**: 고정 실행은 완전해지지만 데스크톱 앱 사용자는 계속 제외된다.
  일상적으로 프로젝트가 옛 lock 에 묶여 있는 경우는 드물고, 그 경우에도 판정은 고정된다.
- **marketplace 를 특정 revision 에 고정한다**: 선언 형식이 브랜치 추적을 전제한다. 고정이
  필요한 경우는 `engsys claude` 가 이미 답이다.

## 영향

- 팀원의 경로가 `clone` 다음 프로젝트를 여는 것으로 끝난다. skill 설치 절차가 없다.
- skill 문구가 `main` 에서 오므로, lock 이 오래된 프로젝트에서는 안내와 판정이 어긋날 수 있다.
  판정이 이기고 거부할 때 선언한 값을 함께 출력하므로 작성자는 정답을 그 자리에서 본다.
- 표준의 `origin` 이 GitHub 이 아니면 선언을 자동으로 쓰지 못한다. 그 사실을 `init` 이 알린다.
- `engsys` 는 여전히 각 머신에 있어야 한다. plugin 은 hook 배선과 skill 을 나르고, 판정하는
  코드는 나르지 않는다. 선언된 hook 은 `engsys` 를 PATH 에서 찾으므로, 없으면 gate 가 돌지 않는다.
  `doctor` 가 그 상태를 보고하고 `pre-push` 가 push 를 막는다.
