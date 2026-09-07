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

## Local use

개발 중에는 shell profile에 한 번만 system command를 연결한다. 이 명령은 파일을 수정하지 않고
shell에 넣을 export문만 출력한다.

```sh
eval "$(/path/to/engineering-system/bin/engsys shellenv)"
```

대상 Git 프로젝트에서는 dependency 설치 없이 adapter만 만든다. `init`은 기존 계약을 절대
덮어쓰지 않으며, manifest를 수동으로 바꾼 뒤에는 `sync`와 `check`를 차례로 실행한다.

```sh
/path/to/engineering-system/bin/engsys init --verify 'make check'
/path/to/engineering-system/bin/engsys check
/path/to/engineering-system/bin/engsys verify
```

`check`는 adapter와 lock만 빠르게 검사한다. `verify`는 그 뒤 project가 선언한 native test와
generated document check를 실행한다. profile 변경과 package 추가는 기존 lock을 바꾸지 않으며,
`engsys upgrade`가 먼저 plan을 보여 준 뒤 `--apply`를 명시해야 반영한다.
적용 시 native test와 generated document check까지 실행하며, 실패하면 이전 lock을 복원한다.

`documentation.generated`는 `output`과 `command`의 순서에 관계없이 읽는다. 각 항목은 두 값을
모두 가진 block mapping이어야 한다. 지원하지 않는 inline mapping·multiline scalar는 오류로
처리한다. 명령에 quote나 escape가 필요하면 single-quoted scalar를 쓴다.

Claude Code는 프로젝트에서 `engsys claude`로 시작한다. launcher가 lock revision의 clean system
worktree를 고른 뒤, lock에 있는 package만 developer-local cache plugin view로 조합한다. 따라서
선택하지 않은 skill·hook은 Claude에 등록되지 않는다.

launcher는 plugin view 경로를 `ENGSYS_PLUGIN_ROOT`로 export한다. skill은 이 변수로만 plugin
안의 스크립트를 실행한다. `CLAUDE_PLUGIN_ROOT`는 hook process 전용이라 skill에서는 비어 있다
([ADR 0003](docs/adr/0003-skill-uses-launcher-environment.md)).

## System development

이 레포를 고칠 때만 필요한 전제가 하나 있다. `tools/`의 검사·생성 도구는 python3 표준
라이브러리를 쓴다. 표준을 채택하는 프로젝트에는 이 전제가 없다
([ADR 0001](docs/adr/0001-posix-sh-core-with-python-tooling.md)).

```sh
sh tests/test-all.sh          # 전체 검사 (이 레포의 commands.verify)
bin/engsys verify --project . # 계약 검사 + 위 test + 생성 문서 최신 여부
```

`docs/generated/`는 사람이 고치지 않는다. `python3 tools/generate-catalog.py`로 다시 만든다.

이 레포의 native 검사에는 `python3 tools/check-documentation.py`도 포함된다. `.engsys/`에
선언한 historical 문서의 필수 frontmatter, policy의 status 목록, local link 대상 존재 여부를
확인한다. 본문을 현행 코드와 비교하거나 외부 URL·heading fragment를 검사하지 않는다.
다른 프로젝트의 문서 검사는 그 프로젝트의 native command가 맡는다.
