---
type: system-design
status: draft
scope: engineering-system-v0.1
---

# Foundation v0.1

## 문제

좋은 정책을 프로젝트마다 복사하면 갱신·적용·검증이 갈라진다. 긴 Markdown을 항상 context에
넣으면 LLM이 핵심 지시를 놓친다.

## 결정 초안

| 질문 | v0.1 기본안 |
|---|---|
| 배포 단위 | 레포 root의 `engsys` plugin 하나. 내부 package·profile로 분리 |
| 활성화 | 개발자 PC에서 한 번. 프로젝트별 dependency·plugin install 없음 |
| 프로젝트 계약 | `.engsys/project.yaml` + `.engsys/lock.yaml` |
| 정책 정본 | `policy.yaml`, schema, 검사 코드 |
| Markdown | route, 짧은 decision record, template만 보관 |
| 강제 | Claude hook은 agent 보조. native test·Git hook·CI가 hard gate |
| update | project lock을 명시적으로 올리는 upgrade workflow |

## Project contract lifecycle

`project.yaml`은 project가 선언한 source-of-truth와 native command다. 버전을 적지 않는다.
`lock.yaml`은 profile이 실제로 해석한 package revision을 고정한다. bootstrap은 둘을 만들고,
upgrade는 먼저 plan을 보여 준 뒤 lock과 generated adapter만 바꾼다.

## Component 경계

| Component | 책임 | 프로젝트에 복사되는가 |
|---|---|---|
| `foundation` | contract, profile, bootstrap, upgrade, compatibility | 아니오 |
| `docs-gov` | lifecycle, impact prompt, generated·historical guardrail | 아니오 |
| `pipeline` | contract check와 project-native verification 순서 | 아니오 |
| profile | package 조합과 language/framework adapter 선택 | 선언만 |
| project manifest | source-of-truth와 native command | 예 |
| lock | 적용 version | 예 |

## 실행 흐름

```text
새 프로젝트 → bootstrap(profile) → manifest + lock + 짧은 Claude route
변경 요청     → classify skill → prompt 또는 native hard gate
시스템 update → upgrade plan → project lock 변경 → 검증
```

## Claude Code 역할

- Skill은 현재 project manifest와 diff를 읽어 판단에 필요한 질문만 낸다.
- Scaffold처럼 write가 있는 skill은 사용자가 명시적으로 호출한다.
- Hook은 generated output 직접 수정처럼 판단이 필요 없는 금지만 막는다.
- Historical record 본문 변경은 v0.1에서 막지 않고 lifecycle skill과 native 검사로 검토한다.
- Hook이 닿지 않는 사람·CI 경로는 project native gate가 동일 규칙을 검사한다.

## 개발자 활성화와 lock

개발자는 clone한 system root의 `engsys shellenv` 출력을 shell profile에 한 번만 등록한다.
프로젝트에서는 `engsys claude`로 Claude Code를 실행한다. 이 launcher는 `.engsys/lock.yaml`의
revision과 같은 clean plugin root를 선택한다. 현재 root가 다르면 cache worktree를 만든다.

따라서 system catalog를 pull한 사실만으로 옛 프로젝트의 skill·hook이 바뀌지 않는다. lock을
바꾸는 길은 `engsys upgrade`의 plan과 명시적 `--apply`뿐이다.

## Context budget

Project route는 12줄 이하로 둔다. skill description은 240자 이하, 본문은 150줄 이하로 둔다.
상세 reference는 skill이 필요할 때만 읽는다. `UserPromptSubmit` classifier와 `Stop` 자동 검증은
매 turn의 context·마찰을 늘리므로 v0.1에서 쓰지 않는다.

## Guardrail matrix

| 대상 | Skill | Claude hook | Native gate |
|---|---|---|---|
| generated output | generator와 정본을 안내 | direct edit 차단 | generator 결과 비교 |
| historical record | lifecycle과 허용 범위를 안내 | 없음 | metadata·link 검사 |
| runtime·DB·API 변경 | 문서 impact 질문 | 없음 | project의 test·schema 검사 |

## Non-goal

- 모든 framework와 CI를 v0.1에 지원하지 않는다.
- LLM이 ADR 필요성이나 문서 내용을 결정하게 하지 않는다.
- 시스템 update가 기존 프로젝트에 자동 반영되게 하지 않는다.

## Pilot success

- 새 fixture project가 dependency 추가 없이 baseline contract를 만든다.
- `public-ai-qa`가 manifest·lock만으로 documentation policy를 연결한다.
- skill의 기본 context는 description과 project route만 포함한다.
- hard gate와 LLM hook의 책임이 겹치지 않는다.

## 다음 설계

1. manifest와 lock의 정확한 lifecycle
2. bootstrap·upgrade input/output
3. docs-gov trigger, prompt, hard gate matrix
4. Claude plugin의 skill·hook contract
