---
type: guide
status: active
---

# Engineering System

프로젝트마다 같은 개발 판단을 반복 가능하게 만드는 실행형 표준이다.

## 경계

- 이 레포는 package, profile, Claude Code plugin, schema, fixture의 정본이다.
- 프로젝트는 `.engsys/project.yaml`과 `.engsys/lock.yaml`으로 선택한 표준과 버전을 선언한다.
- 공통 정책·skill·hook을 프로젝트에 복사하지 않는다.
- Claude Code skill·hook handler는 각 package가 소유한다. launcher는 lock의 package만 local cache
  plugin view로 조합한다.
- 확정적인 규칙은 프로젝트 native test·Git hook·CI가 검사한다.

## v0.1

첫 package는 `foundation`, `docs-gov`, `pipeline`이다. 이 레포 자신이 첫 pilot이며,
`.engsys/`로 자기 표준을 채택하고 있다.

- [Current architecture](docs/architecture/README.md) — 지금 어떻게 되어 있는가
- [Architecture Decision Record](docs/adr) — 그 뒤로 왜 바뀌었는가
- [Foundation design](docs/design/0001-foundation.md) — 그때 왜 이렇게 설계했는가
- [System catalog](docs/generated/system-catalog.md) — 선언에서 생성되는 package·skill 목록
- [Project contract schema](schemas/project.schema.json)
- [Project lock schema](schemas/lock.schema.json)
- [Baseline profile](profiles/baseline.yaml)
- [Bootstrap workflow](workflows/bootstrap.yaml)

## 활성화

팀원은 이 레포를 clone한 뒤 한 번만 실행한다. 개발자 자신의 shell profile과 이 clone의 Git hook
경로만 바꾸며, 프로젝트에는 아무것도 쓰지 않는다.

```sh
git clone https://github.com/pis-o-cake/engineering-system
cd engineering-system && ./install.sh
```

`--print`를 주면 profile에 넣을 줄만 출력한다. profile에 이미 다른 checkout을 가리키는 줄이
있으면 덮지 않고 그 줄을 알려 준다.

활성화 상태는 언제든 `engsys doctor`로 확인한다. PATH 연결, locked revision을 이 clone에서
가져올 수 있는지, 계약이 `engsys check`를 통과하는지, origin/main에 더 새 revision이 있는지를
보고하고 각각 실행할 명령을 알려 준다.

```sh
engsys doctor --project /path/to/project
```

## 표준 버전 올리기

배포 채널은 `origin/main`이다. lock은 명령을 실행한 개발자의 system checkout revision을 기록하므로,
올리기 전에 checkout을 원하는 지점에 둔다. 특정 release에 고정하려면 그 tag를 checkout한다.

```sh
git -C /path/to/engineering-system checkout main && git -C /path/to/engineering-system pull
engsys upgrade --project /path/to/project            # plan만 출력
engsys upgrade --project /path/to/project --apply
```

프로젝트를 검사하는 명령(`check`·`sync`·`verify`·`docs`·`review`·`vcs`)은 **그 프로젝트가 lock한
revision에서 실행된다.** PATH의 `engsys`는 실행기이고, 판정하는 코드는 lock이 가리키는 release에서
온다. 그래서 팀원이 어느 branch를 checkout해 두었든 같은 결과를 얻는다. `init`·`upgrade`·`doctor`는
넘기지 않으며, 표준을 고치는 중에는 `ENGSYS_USE_CHECKOUT=1`로 자기 수정을 쓸 수 있다
([ADR 0012](docs/adr/0012-project-commands-run-at-the-locked-revision.md)).

`engsys verify --revision <commit>`은 working tree가 그 commit과 같은지 먼저 확인하고 다르면
무엇이 다른지 출력한 뒤 중단한다. 기본 `pre-push`가 이 형태로 부르므로, gate는 검사한 내용과
전송하는 내용이 같을 때만 통과한다
([ADR 0013](docs/adr/0013-the-push-gate-judges-the-commit-it-sends.md)).

`--apply`는 새 lock으로 native test와 generated document check까지 실행하고, 실패하면 이전 lock을
복원한다. `doctor`는 lock이 아직 `origin/main`에 없으면 경고한다. 그 상태로 프로젝트를 push하면
팀원의 clone이 그 revision을 fetch하지 못한다.

## 프로젝트 채택

대상 Git 프로젝트에서는 dependency 설치 없이 adapter만 만든다. `init`은 기존 계약을 절대
덮어쓰지 않으며, manifest를 수동으로 바꾼 뒤에는 `sync`와 `check`를 차례로 실행한다.

```sh
engsys init --project /path/to/project --detect --hooks
engsys verify --project /path/to/project
```

`--detect`는 설정하지 않은 선언만 프로젝트에서 읽어 채우고 채운 값을 모두 출력한다 — native 검증
명령, source-of-truth 디렉토리, 문서 정본 경로, lifecycle, 그리고 아직 문서가 없는 경로의 유형
배정이다. 이미 문서가 있는 경로는 배정하지 않고 그 경로를 알려 준다. 유형을 선언하지 않은 문서를
배정하면 채택 첫날 검사가 전부 실패하기 때문이다. 명시한 옵션이 언제나 감지보다 우선한다.

감지는 최상위 디렉토리만 본다. `backend/pyproject.toml`처럼 한 단계 아래에 있는 스택은 찾지
못하므로 `--verify 'cd backend && poe check'`처럼 직접 준다.

복사한 hook은 프로젝트가 소유하므로 표준이 덮어쓰지 않는다. template이 바뀌었는지는
`engsys hooks status`가 알린다.

```sh
engsys hooks status --project /path/to/project
engsys hooks update --project /path/to/project           # 고치지 않은 사본만 갱신
engsys hooks update --project /path/to/project --adopt   # 사본을 유지하고 확인만 기록
```

고친 사본은 `--force` 없이 바뀌지 않는다. 기록은 `.engsys/hooks.txt`에 남으며 프로젝트가 commit한다
([ADR 0015](docs/adr/0015-hook-copies-are-diagnosed-not-overwritten.md)).

`--hooks`는 `pre-push` gate를 프로젝트에 복사하고 `core.hooksPath`가 비어 있을 때만 등록한다.
그 파일은 프로젝트가 소유하며 표준이 나중에 덮어쓰지 않는다
([ADR 0008](docs/adr/0008-init-detects-declarations-and-seeds-the-project-gate.md)).

`check`는 adapter와 lock만 빠르게 검사한다. `verify`는 그 뒤 project가 선언한 native test와
generated document check를 실행한다. profile 변경과 package 추가는 기존 lock을 바꾸지 않는다 —
반영은 위 "표준 버전 올리기"의 `upgrade`가 맡는다.

`documentation.generated`는 `output`과 `command`의 순서에 관계없이 읽는다. 각 항목은 두 값을
모두 가진 block mapping이어야 한다. 지원하지 않는 inline mapping·multiline scalar는 오류로
처리한다. 명령에 quote나 escape가 필요하면 single-quoted scalar를 쓴다.

Claude Code는 프로젝트에서 `engsys claude`로 시작한다. launcher가 lock revision의 clean system
worktree를 고른 뒤, lock에 있는 package만 developer-local cache plugin view로 조합한다. 따라서
선택하지 않은 skill·hook은 Claude에 등록되지 않는다.

launcher는 plugin view 경로를 `ENGSYS_PLUGIN_ROOT`로 export한다. skill은 이 변수로만 plugin
안의 스크립트를 실행한다. `CLAUDE_PLUGIN_ROOT`는 hook process 전용이라 skill에서는 비어 있다
([ADR 0003](docs/adr/0003-skill-uses-launcher-environment.md)).

## 시스템 레포 개발

이 레포를 고칠 때만 필요한 전제가 하나 있다. `tools/`의 검사·생성 도구는 python3 표준
라이브러리를 쓴다. 표준을 채택하는 프로젝트에는 이 전제가 없다
([ADR 0001](docs/adr/0001-posix-sh-core-with-python-tooling.md)).

```sh
sh tests/test-all.sh          # 전체 검사 (이 레포의 commands.verify)
bin/engsys verify --project . # 계약 검사 + 위 test + 생성 문서 최신 여부
```

CI runner가 준비되기 전까지는 push 전 검사를 Git hook으로 강제한다. `pre-push`가
`sh tests/test-all.sh`와 전송할 commit의 문서 검토 검사를 실행한다. 등록은 `install.sh`가 하며,
등록 여부는 `engsys doctor`가 보고한다. CI가 열리면 같은 명령을 그대로 옮긴다.

native 검사에는 self lock 신선도 확인이 있다. `packages/`·`bin/`·`lib/`를 바꾸는 commit 뒤에는
`bin/engsys upgrade --project . --apply`로 자기 lock을 올리고 그 lock 변경을 커밋한다.
그러지 않으면 `engsys claude`가 병합 전 revision의 skill·hook을 조합한다.

`docs/generated/`는 사람이 고치지 않는다. `python3 tools/generate-catalog.py`로 다시 만든다.

이 레포의 native 검사에는 `python3 tools/check-documentation.py`도 포함된다. `.engsys/`에
선언한 historical 문서의 필수 frontmatter, policy의 status 목록, local link 대상 존재 여부를
확인한다. 본문을 현행 코드와 비교하거나 외부 URL·heading fragment를 검사하지 않는다.
다른 프로젝트의 문서 검사는 그 프로젝트의 native command가 맡는다.

## 커밋과 merge request 규약

커밋 헤더 포맷, type 목록, subject 길이, 금지 trailer, MR 본문 필수 절의 정본은
[commit contract](packages/vcs-gov/commit-contract.yaml)이다. 프로젝트는 `.engsys/project.yaml`의
`vcs` 블록에 값만 선언한다 — subject 언어와 종결 어미, `scope` 목록, branch model, MR 대상 branch.

```sh
engsys vcs check-message .git/COMMIT_EDITMSG --project .
```

`engsys init --hooks`가 심는 `commit-msg` hook이 같은 검사를 한다. 커밋은 세션 밖에서도 생기므로
강제는 Claude Code hook이 아니라 native git hook이 맡는다. 작성은 `/engsys:write-commit`과
`/engsys:write-merge-request`가 돕는다.

branch model은 역할과 분기·승격 방향만 정의한다. 실제 이름은 프로젝트가 정한다.

```yaml
vcs:
  branch:
    model: 'env-branch'
    roles:                    # 선언 순서가 승격 순서다
      - role: 'development'
        branch: 'develop'
      - role: 'production'
        branch: 'main'
    prefixes:
      feature: 'feat/'
      hotfix: 'hotfix/'
```

선언하지 않으면 계약의 기본값을 쓰되 model이 요구하는 역할만 남는다. `engsys vcs base-branch`가
분기 기준을 답하고 `engsys vcs settings`가 해석된 값을 보여 준다. hook과 skill은 이 명령을 쓰고
branch 이름을 직접 적지 않는다. 잘못된 선언은 `engsys verify`의 `check-settings`가 잡는다.

이 선언은 로컬 규칙이다. **Git 서버의 protected branch 설정은 여기서 적용되지 않는다.**

branch 이름 규칙은 model의 `naming`이 기본값이고, 프로젝트가 `vcs.branch.naming`에 pattern을
선언하면 그것이 이긴다. 선언했을 때만 `engsys vcs check-branch`가 판정하며 push gate가 그것을
부른다. protected branch와 detached HEAD는 대상이 아니다.

기계가 판정할 수 있는 것만 막는다. `·` 나열처럼 커밋을 쪼갤 신호는 경고로 남기고 통과시킨다
([ADR 0011](docs/adr/0011-vcs-gov-owns-the-commit-and-merge-request-contract.md)).

## 문서 유형과 구조 검사

새 문서는 유형을 먼저 정한다. 유형별 독자, 답할 질문, 필수 metadata, 필수 절의 정본은
[document types](packages/docs-gov/document-types.yaml)이고, 프로젝트는 `.engsys/project.yaml`의
`documentation.authoring`에서 경로에 유형을 배정한다. `/engsys:write-document`가 작성 전에 그
계약을 읽는 절차를 제공한다.

```sh
engsys docs check --project .
```

`--path <문서>`를 주면 그 문서 하나만 본다. 배정되지 않은 경로와 없는 파일은 오류가 아니다.

`engsys claude`로 연 세션에서는 이 검사가 자동으로 돈다. 문서를 쓴 직후 그 문서 하나가 검사되고,
실패하면 결과가 Claude에게 전달돼 그 자리에서 고친다. 세션을 열 때는 검토 기록이 없는 문서 수가
한 줄로 주입된다. 사람이 에디터로 직접 고친 문서는 이 층에 걸리지 않으며 push gate가 잡는다
([ADR 0009](docs/adr/0009-document-structure-feedback-at-write-time.md)).

배정된 문서의 유형·status·필수 metadata·근거 경로·도입 문단·필수 절을 검사한다. 유형의
`frozen-status`에 해당하는 기록은 절의 존재만 보고 순서는 강제하지 않으며, `deferred`로 선언한
경로는 절 검사를 유예하고 metadata만 검사한다. 구조 검사는 문체를 판정하지 않는다
([ADR 0006](docs/adr/0006-document-type-contract-in-posix-sh.md)).

## 문서 편집 검토

보고·운영·설계 문서는 [편집 기준](packages/docs-gov/editorial.md)에 따라 한 편씩 읽고 수정한다.
`/engsys:review-document`가 최종본을 검토하고 문서별 기록을 남기는 절차를 제공한다.
기록에는 본문 해시, 검토자, 독자, 문서가 답할 질문, 구체적인 검토 내용을 담는다.

```sh
engsys review status
engsys review record --document docs/report.md --blob <검토한-본문-해시> \
  --reviewer <실제-검토자> --audience <독자> --purpose <답할-질문> --notes-file <검토-메모>
engsys review check
```

검사 범위의 정본은 계약의 `documentation.review.scopes`다. `--scope`를 주지 않으면 그 목록을
읽으므로 프로젝트 hook이 같은 목록을 다시 파싱하지 않는다. 프로젝트는 `engsys review check`를
native 검사에 연결한다. 생성 문서는 제외되며, 새 문서나 검토 후 바뀐 문서는 실패한다. 기존
문서를 범위에 넣을 때도 최초 개별 검토가 필요하다. 문서와 `.engsys/reviews/`의 해당 기록을
함께 commit한다. 전체 문체를 자동 판정하거나 일괄 승인하지 않는다.

push gate에서는 `engsys review check --revision <전송할-commit>`으로 전송할 본문과 기록을 함께
검사한다. 범위와 생성 문서 목록도 그 commit의 계약에서 읽는다. 이 레포는 `.githooks/pre-push`에
연결한다. 검사는 검토 기록의 존재와 신선도를 확인하며, 글의 품질이나 상급자의 승인을 증명하지
않는다.
