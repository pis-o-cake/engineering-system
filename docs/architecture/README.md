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
- `lib/generated-documents.awk` — `documentation.generated`를 항목 단위로 읽는 core parser다.
  `output`·`command` 순서는 자유이며, 누락·중복·지원하지 않는 문법은 오류로 처리한다.
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

`engsys upgrade --apply`는 새 lock으로 위 verify 경로를 실행한다. 성공하면 새 lock을 유지하고,
실패하거나 중단되면 이전 lock을 복원한다. native command가 바꾼 프로젝트 파일은 그 command의
책임이며 lock 복원의 대상이 아니다.

## 강제 지점

| 대상 | Claude hook | Native gate |
|---|---|---|
| 생성 문서 직접 수정 | `PreToolUse`에서 차단 | `engsys verify`가 generator 결과와 비교 |
| 계약 형식 | 없음 | `engsys check` + `tools/validate-contract.py` |
| 카탈로그 사본 일치 | 없음 | `tools/check-consistency.py` |
| 이 레포의 historical metadata·local link | lifecycle skill의 검토 안내 | `tools/check-documentation.py` |
| self lock 신선도 | 없음 | tests가 lock revision과 HEAD의 `packages`·`bin`·`lib` tree 비교 |

hook은 사람이 우회할 수 있으므로 정본이 아니다. 같은 규칙을 native gate가 다시 검사한다.
CI runner가 준비되기 전까지 push 전 강제는 `.githooks/pre-push`가 맡는다
(`git config core.hooksPath .githooks`로 1회 활성화). CI가 열리면 같은 명령을 옮긴다.

Historical 검사는 `.engsys/project.yaml`의 lifecycle 경로와 docs-gov policy의 필수 metadata·status
목록을 읽는다. `tests/test-all.sh`에 연결되므로 이 레포의 `engsys verify`에서도 실행된다.
과거 본문과 현행 code의 일치 여부는 검사하지 않는다. 외부 URL과 heading fragment도 범위 밖이다.
이 python 도구는 시스템 레포의 native 검사이며, 채택 프로젝트는 자기 native 문서 검사를 선언한다.
