---
type: current-architecture
status: living
scope: engineering-system
---

# Current architecture

이 문서는 **지금 시스템이 어떻게 되어 있는지**만 설명한다. 설계 당시의 판단은
[design](../design)에, 그 뒤의 변경 이유는 [ADR](../adr)에 있다.

package·skill·hook의 목록과 version처럼 선언에서 결정적으로 얻을 수 있는 사실은 여기에 옮겨
적지 않는다. [system catalog](../generated/system-catalog.md)가 `tools/generate-catalog.py`로
생성되며, 그 문서가 최신인지는 `engsys verify`가 검사한다.

## 구성 요소

- `bin/engsys` — 프로젝트가 실행하는 유일한 진입점. dependency 없는 POSIX sh다.
  계약 생성(`init`), 검사(`check`), 프로젝트 검증(`verify`), lock 변경(`upgrade`),
  Claude Code 실행(`claude`)을 담당한다.
- `packages/*` — 정책과 Claude Code skill·hook의 정본. 프로젝트에 복사되지 않는다.
- `profiles/*` — package 조합 선언.
- `schemas/*` — 프로젝트 계약과 lock 형식의 정본.
- `tools/*` — 시스템 레포 개발용 도구(python3). 프로젝트는 실행하지 않는다.

## 실행 경로

```text
engsys claude
  → lock revision의 clean worktree 선택
  → lock의 package만 모은 plugin view 생성 (개발자 로컬 cache)
  → ENGSYS_PLUGIN_ROOT export 후 project root에서 claude --plugin-dir 실행
```

```text
engsys verify
  → engsys check (adapter·lock 구조 검사)
  → commands.verify (프로젝트가 선언한 native 검증)
  → documentation.generated[].command (생성 문서 최신 여부)
```

## 강제 지점

| 대상 | Claude hook | Native gate |
|---|---|---|
| 생성 문서 직접 수정 | `PreToolUse`에서 차단 | `engsys verify`가 generator 결과와 비교 |
| 계약 형식 | 없음 | `engsys check` + `tools/validate-contract.py` |
| 카탈로그 사본 일치 | 없음 | `tools/check-consistency.py` |

hook은 사람이 우회할 수 있으므로 정본이 아니다. 같은 규칙을 native gate가 다시 검사한다.
