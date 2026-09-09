---
type: current-architecture
status: active
scope: engineering-system
last-reviewed: 2026-09-08
---

# Current architecture

이 문서는 **지금 시스템이 어떻게 되어 있는지**만 설명한다. 설계 당시의 판단은
[design](../design)에, 그 뒤의 변경 이유는 [ADR](../adr)에 있다.

package·skill·hook의 목록과 version처럼 선언에서 결정적으로 얻을 수 있는 사실은 여기에 옮겨
적지 않는다. [system catalog](../generated/system-catalog.md)가 `tools/generate-catalog.py`로
생성되며, 그 문서가 최신인지는 `engsys verify`가 검사한다.

## 구조 요약

시스템은 세 층이다. `packages/*`가 정책과 Claude Code skill·hook의 정본을 갖고, `profiles/*`가
그 조합을 선언하며, 채택 프로젝트는 `.engsys/project.yaml`과 `.engsys/lock.yaml`로 계약을 선언한다.
이 밖에 프로젝트가 소유하는 hook 사본과 검토 기록 등을 관리한다.
정책 파일은 프로젝트에 복사되지 않는다.

프로젝트가 실행하는 명령은 `bin/engsys` 하나다. lock이 어느 revision의 어떤 package를 쓸지
고정하므로, 시스템 레포를 pull해도 기존 프로젝트의 skill·hook 조합은 바뀌지 않는다.

## 구성 요소

- `bin/engsys` — 프로젝트가 실행하는 유일한 진입점. dependency 없는 POSIX sh다.
  `setup`만 대화형이며, 나머지는 CI와 script가 부를 수 있도록 비대화형으로 둔다.
  계약 생성(`init`), 검사(`check`), 진단(`doctor`), 프로젝트 검증(`verify`), 문서 구조 검사(`docs`),
  문서 검토(`review`), lock 변경(`upgrade`), Claude Code 실행(`claude`)을 담당한다.
- `install.sh` — 개발자 활성화. shell profile 한 줄과 이 clone의 `core.hooksPath`만 바꾼다.
  프로젝트에는 쓰지 않는다 ([ADR 0007](../adr/0007-one-command-activation-and-main-as-release-channel.md)).
- `lib/plugin-runtime.sh` — lock revision의 cache와 Claude plugin view 조합.
- `lib/adoption.sh` — hook 사본 진단·갱신, guided setup, doctor.
- `lib/generated-documents.awk` — `documentation.generated`를 항목 단위로 읽는 core parser다.
  `output`·`command` 순서는 자유이며, 누락·중복·지원하지 않는 문법은 오류로 처리한다.
- `packages/*` — 정책과 Claude Code skill·hook의 정본. 프로젝트에 복사되지 않는다.
  `docs-gov`는 문서 유형과 편집 검토를, `vcs-gov`는 커밋·MR 규약을 갖는다.
- `templates/project/*` — 프로젝트가 복사해 소유하는 seed. Claude route rule과 Git hook이며,
  복사한 뒤에는 프로젝트의 파일이다. 표준이 덮어쓰지 않고 `engsys hooks status`가 차이만 알린다.
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
engsys <check|sync|verify|docs|review|vcs> --project P
  → P의 lock revision이 이 checkout의 commit과 다르거나 checkout에 미커밋 수정이 있으면
      그 revision의 clean worktree를 확보하고 그쪽 bin/engsys로 실행을 넘김
  → locked revision을 준비하지 못하거나 cache가 수정됐으면 실패
  → init·upgrade·doctor·claude는 넘기지 않는다
  → 자기 레포와 명시적인 ENGSYS_USE_CHECKOUT=1은 개발 중인 코드를 실행
```

```text
engsys verify --revision <commit>
  → working tree가 그 commit과 같은지 단언 (다르면 무엇이 다른지 출력하고 중단)
  → 아래 verify 경로를 실행하고, 판정한 commit과 표준 revision을 출력
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

| 대상 | Claude 보조 경로 | Native gate |
|---|---|---|
| 생성 문서 직접 수정 | `PreToolUse`에서 차단 | `engsys verify`가 generator 결과와 비교 |
| 계약 형식 | 없음 | `engsys check`가 최상위 key·필수 항목·선언한 block이 읽혔는지 검사. 전체 형식은 `tools/validate-contract.py` |
| 카탈로그 사본 일치 | 없음 | `tools/check-consistency.py` |
| 이 레포의 historical metadata·local link | lifecycle skill의 검토 안내 | `tools/check-documentation.py` |
| 커밋 메시지 | `write-commit` skill이 계약과 프로젝트 선언을 읽음 | 프로젝트의 `commit-msg` hook이 `engsys vcs check-message` 실행 |
| branch 이름 | `write-commit` skill이 `engsys vcs base-branch`로 분기 기준을 물음 | 프로젝트가 `vcs.branch.naming`을 선언했을 때만 push gate가 `engsys vcs check-branch` 실행 |
| branch 설정 | 없음 | `vcs` 선언이 있으면 `engsys verify`가 `engsys vcs check-settings` 실행 |
| 문서 유형·필수 구성 | `write-document` skill이 작성 전 유형과 계약을 읽고, `PostToolUse`가 방금 쓴 문서 하나를 검사해 결과를 세션에 돌려줌 | `engsys docs check`가 선언한 유형·metadata·절·근거 경로 검사 |
| authored 문서의 편집 검토 | `review-document` skill로 개별 검토 | `engsys review check`가 문서별 검토 기록과 본문 해시 비교 |
| self lock 신선도 | 없음 | tests가 lock revision과 HEAD의 `packages`·`bin`·`lib` tree 비교 |

hook은 사람이 우회할 수 있으므로 정본이 아니다. 같은 규칙을 native gate가 다시 검사한다.
CI runner가 준비되기 전까지 push 전 강제는 `.githooks/pre-push`가 맡는다
(`git config core.hooksPath .githooks`로 1회 활성화). CI가 열리면 같은 명령을 옮긴다.

Historical 검사는 `.engsys/project.yaml`의 lifecycle 경로와 docs-gov policy의 필수 metadata·status
목록을 읽는다. `tests/test-all.sh`에 연결되므로 이 레포의 `engsys verify`에서도 실행된다.
과거 본문과 현행 code의 일치 여부는 검사하지 않는다. 외부 URL과 heading fragment도 범위 밖이다.
이 python 도구는 시스템 레포의 native 검사이며, 채택 프로젝트는 자기 native 문서 검사를 선언한다.

## 문서 유형 구조 검사

`packages/docs-gov/document-types.yaml`이 유형별 독자·질문·필수 metadata·필수 절의 정본이다.
프로젝트는 `.engsys/project.yaml`의 `documentation.authoring`에서 경로에 유형을 배정하고,
검사에서 제외할 경로(`exempt`)와 절 검사를 유예할 경로(`deferred`)를 선언한다.

`engsys docs check`는 배정된 문서마다 선언한 유형이 배정과 같은지, status가 유형의 어휘에 있는지,
필수 metadata가 채워졌는지, metadata가 가리키는 근거 경로가 존재하는지, 첫 절 앞에 도입 문단이
있는지, 필수 절이 있는지를 본다. 유형의 `frozen-status`에 해당하는 기록은 절의 존재만 보고
순서는 보지 않는다. HTML은 `<meta name="doc-*">`로 같은 metadata를 선언한다.

검사는 세 시점에 돈다. 문서를 쓴 직후 `PostToolUse` hook이 `--path`로 **그 문서 하나만** 보고,
실패하면 exit 2로 끝내 그 결과가 세션 안의 Claude에게 전달된다. 세션을 열 때 `SessionStart` hook은
검토 기록이 없는 문서 수만 세고 구조는 다시 보지 않는다. 마지막으로 `engsys verify`와 push gate가
전체를 본다. 턴마다 전체를 검증하는 `Stop` hook은 쓰지 않는다
([ADR 0009](../adr/0009-document-structure-feedback-at-write-time.md)).

이 검사는 구조만 판정한다. `validate-document.awk`가 문서 하나의 metadata와 절을 한 번에
판정하고, shell은 경로와 실제 참조 파일 존재를 확인한다. 문장의 적절성과 근거의 충분성은
아래 편집 검토가 판단한다.

## 문서별 편집 검토

`packages/docs-gov/editorial.md`는 보고·설계·운영 문서의 독자와 목적에 따른 편집 기준이다.
검토자는 문서 전체를 읽고 편집한 뒤 최종본을 다시 읽는다. `engsys review record`는 문서 하나의
해시와 검토 내용을 `.engsys/reviews/<document-path>.review`에 남긴다.

`engsys review check`는 계약의 `documentation.review.scopes`에서 범위를 읽어, 그 범위의
Markdown·HTML 중 생성 문서를 제외하고 검토 기록을 대조한다. 새로운 문서와 검토 후 변경한
문서는 실패한다. `--revision <commit>`을 주면 범위·생성 문서 목록·본문을 모두 그 commit에서
읽어, working tree의 후속 수정이 push할 문서의 검토를 대신하지 못하게 한다.
이 검사는 문체를 자동 채점하거나 실제로 읽었는지를 증명하지 않는다.

## 제약과 근거

- 프로젝트가 실행하는 명령은 dependency 없는 POSIX sh만 쓴다. python3를 쓰는 `tools/*`는 시스템
  레포 기여자 전용이다 ([ADR 0001](../adr/0001-posix-sh-core-with-python-tooling.md)).
- 계약 형식의 정본은 `schemas/*.json`이고 `engsys check`는 근사다. 형식을 바꾸면 schema를 먼저
  고친다 ([ADR 0002](../adr/0002-contract-schema-is-canonical.md)).
- skill은 `ENGSYS_PLUGIN_ROOT`로만 plugin에 닿는다. `CLAUDE_PLUGIN_ROOT`는 hook 전용이다
  ([ADR 0003](../adr/0003-skill-uses-launcher-environment.md)).
- 이 레포가 자기 표준의 첫 pilot이므로, 표준을 바꾸면 이 레포의 계약과 문서가 먼저 깨진다
  ([ADR 0004](../adr/0004-self-hosted-first-pilot.md)).
- 검토 기록의 존재는 글의 품질이나 승인을 증명하지 않는다
  ([ADR 0005](../adr/0005-individual-document-editorial-review.md)).
- 문서 유형 계약은 구조만 강제한다. 유형별 규칙을 프로젝트에 복사하지 않는다
  ([ADR 0006](../adr/0006-document-type-contract-in-posix-sh.md)).
- 배포 채널은 `origin/main`이고 lock은 실행한 checkout의 revision을 기록한다. `doctor`는 진단만
  하고 고치지 않는다 ([ADR 0007](../adr/0007-one-command-activation-and-main-as-release-channel.md)).
- `init --detect`는 설정하지 않은 선언만 채우고, 이미 문서가 있는 경로에는 유형을 배정하지 않는다
  ([ADR 0008](../adr/0008-init-detects-declarations-and-seeds-the-project-gate.md)).
- 구조 검사는 작성 시점에 문서 하나 단위로 돌고 결과는 Claude가 받는다. 편집 검토는 옮기지 않는다
  ([ADR 0009](../adr/0009-document-structure-feedback-at-write-time.md)).
- `SessionStart`는 검토 backlog만 센다. 전체 구조 검사를 세션마다 돌 값이 없었다
  ([ADR 0010](../adr/0010-session-start-counts-review-backlog-only.md)).
- push gate는 전송할 commit을 판정한다. 검사 대상이 그 commit과 다르면 중단한다
  ([ADR 0013](../adr/0013-the-push-gate-judges-the-commit-it-sends.md)).
- 프로젝트 명령은 그 프로젝트가 lock한 revision에서 실행한다. 실행한 개발자의 checkout이 판정을
  바꾸지 않는다 ([ADR 0012](../adr/0012-project-commands-run-at-the-locked-revision.md)).
- 문서 뼈대는 서식만 채운다. 빈 절은 구조 검사가 잡는다
  ([ADR 0016](../adr/0016-a-scaffold-fills-the-form-not-the-writing.md)).
- 프로젝트가 복사한 hook은 진단하고 덮어쓰지 않는다. 기록은 template 해시와 사본 해시 둘이다
  ([ADR 0015](../adr/0015-hook-copies-are-diagnosed-not-overwritten.md)).
- 채택은 `setup`이 단계마다 확인하고 진행한다. 파일을 바꾸기 전에 무엇을 바꿀지 보여 준다
  ([ADR 0018](../adr/0018-adoption-is-a-guided-sequence.md)).
- 표준은 branch 이름을 갖지 않는다. 선언하지 않으면 도구가 답하지 않는다
  ([ADR 0017](../adr/0017-the-standard-holds-no-branch-names.md)).
- branch model은 역할과 승격 방향만 정의하고 이름은 프로젝트가 선언한다. 도구는 그 선언을 읽고
  이름을 하드코딩하지 않는다 ([ADR 0014](../adr/0014-projects-name-their-branches.md)).
- 커밋·MR 규약은 `vcs-gov`가 갖고 프로젝트는 값만 선언한다. 커밋은 세션 밖에서도 생기므로 강제는
  native git hook이 맡는다
  ([ADR 0011](../adr/0011-vcs-gov-owns-the-commit-and-merge-request-contract.md)).
