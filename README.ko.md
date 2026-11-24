---
type: guide
status: active
---

# Engineering System

[English](README.md) | **한국어**

프로젝트마다 같은 개발 판단을 반복 가능하게 만드는 실행형 표준.

## 경계

- 정본 위치: 이 레포 — package, profile, Claude Code plugin, schema, fixture
- 프로젝트 선언: `.engsys/project.yaml`·`.engsys/lock.yaml`로 사용할 표준과 버전 지정
- 공통 정책·skill·hook의 프로젝트 복사 금지
- skill·hook handler 소유: 각 package. launcher는 lock에 든 package만 local cache plugin view로 조합
- 확정 규칙 검사: 프로젝트 native test·Git hook·CI

## v0.1

- 현재 package: `foundation`, `docs-gov`, `vcs-gov`, `pipeline`
- 첫 pilot: 이 레포 자신. `.engsys/`로 자기 표준 채택 중

- [Current architecture](docs/architecture/README.md) — 현재 구조
- [Architecture Decision Record](docs/adr) — 이후 변경 이유
- [Foundation design](docs/design/0001-foundation.md) — 초기 설계 이유
- [System catalog](docs/generated/system-catalog.md) — 선언에서 생성한 package·skill 목록
- [Project contract schema](schemas/project.schema.json)
- [Project lock schema](schemas/lock.schema.json)
- [Baseline profile](profiles/baseline.yaml)
- [Bootstrap workflow](workflows/bootstrap.yaml)
- [Adoption evaluation](docs/verification/adoption.md) — 효과·실행 비용 판단 기준

## 처음 붙일 때

- 표준 clone: 한 번
- 프로젝트별 선언: 계약 파일 두 개(표준·버전)
- 계약 생성·Git hook 연결: 아래 `setup`이 안내

### 1. 표준 clone·활성화 — 컴퓨터당 한 번

```sh
git clone https://github.com/pis-o-cake/engineering-system
cd engineering-system
./install.sh
```

- `install.sh` 변경 범위: 두 가지
  - shell profile(`~/.zshrc` 등)에 `engsys` PATH 한 줄 추가
  - 이 clone의 Git hook 경로 설정
- 다른 프로젝트: 변경 없음
- 되돌리기: 추가된 그 줄 삭제
- 완료 후 **새 터미널 필요** — 그래야 `engsys` 인식

### 2. 대상 프로젝트에서 setup 실행 — 프로젝트당 한 번

```sh
cd /내/프로젝트
engsys setup
```

- 경로 인자 불필요. 대상: 현재 디렉토리
- 진행: 여덟 단계 순차

| 단계 | 내용 |
|---|---|
| 1. 전제 도구 | `git` 존재 확인. `python3`·Claude Code는 선택, 없으면 안 되는 기능 안내 |
| 2. 시스템 checkout | 표준 revision, 팀원 fetch 가능 여부 확인 |
| 3. 개발자 활성화 | `engsys` PATH 확인. 없으면 `install.sh` 실행 여부 질문 |
| 4. 대상 프로젝트 | 검사 명령·소스 경로·branch 이름 **감지 → 계약 전문 미리 표시 → 생성 여부 질문** |
| 5. Git hook | `commit-msg`·`pre-push` 설치 여부, `core.hooksPath` 미설정 시 설정 여부 질문. 고쳐 쓰던 hook은 덮지 않음 |
| 6. 검사 | 계약 유효성 확인, 프로젝트 기존 test 실행 여부 질문 |
| 7. 최종 진단 | `doctor` 재실행. 남은 문제 있으면 성공 처리 안 함 |
| 8. 남은 것 | 미선언 항목·commit 대상 파일 안내 |

- **파일 변경 전 항상 미리 표시 후 질문**
- 질문 생략: `--yes`
- 터미널 없음 + `--yes` 없음 → 시작 안 함. 이유: 질문 불가 상태로 진행 시 아무것도 안 한 채 성공처럼 종료

### 3. 생성 파일 commit

```sh
git add .engsys .githooks .claude
git commit -m "build(engsys): Engineering System 계약 추가"
```

- 이 파일들이 있어야 팀원이 같은 계약 수신

### 팀원 할 일

- `.claude/settings.json`에 표준이 marketplace로 선언됨 → Claude Code로 열면 skill·문서 guardrail **자동 부착**
- CLI·데스크톱 앱·IDE 확장 공통. `engsys claude` 몰라도 무방
  ([ADR 0023](docs/adr/0023-the-standard-ships-as-a-plugin-marketplace.md))
- **단, plugin은 판정 코드 미포함**
  - 부착 대상: skill·hook 배선
  - hook 동작: PATH의 `engsys` 호출
  - `engsys` 없음 → 부착돼도 판정 없음. `engsys doctor`가 실패로 보고
- 결과: 아래 두 가지는 팀원 각자 한 번씩 필요

```sh
git clone https://github.com/pis-o-cake/engineering-system && cd engineering-system && ./install.sh
cd /내/프로젝트 && engsys setup
```

- **`install.sh`** — 판정 코드(`engsys`)는 plugin이 나르지 않음. 머신마다 설치 필요
- **`engsys setup`** — `core.hooksPath` 설정. `.git/config`에 있어 **commit 안 됨** → clone만으로 전달 불가. 미설정 시 hook 파일이 있어도 Git이 호출 안 함
- 둘 다 건너뛰고 push → `pre-push`가 원인 안내 후 차단

### 실패 시

- 롤백 없음
- 마지막에 멈춘 단계·다음 할 일 재표시
- 전체 출력 파일 보존 — 터미널이 닫혀도 유지

```
멈춘 곳: [4] 대상 프로젝트
위의 마지막 오류 줄이 이유다. 아무것도 되돌리지 않았으니 고치고 다시 실행하면 된다.

  지금 상태 보기 : engsys doctor --project /내/프로젝트
  다시 실행      : engsys setup --project /내/프로젝트
  전체 기록      : /tmp/engsys-setup-4471.log
```

- 원인 수정 후 `engsys setup` 재실행. 완료 단계는 그대로 통과

### 상태 확인

```sh
engsys doctor      # 빠진 것과 각각을 고치는 명령
engsys verify      # 계약·문서·프로젝트 test 전체 실행
```

- `doctor`: 진단 전용, 수정 없음. 안내받은 명령은 직접 실행

### Windows

- 실행 환경: Git Bash 전용
- 이유
  - `bin/engsys`: 확장자 없는 POSIX sh → PowerShell·CMD 실행 불가
  - `install.sh`: bash 로그인 프로필만 수정 → 두 셸 PATH에 반영 없음
- 증상: 활성화 후에도 PowerShell 응답

```
The term 'engsys' is not recognized as the name of a cmdlet, function, script file, ...
```

- 의미: 설치 실패 아님, 셸 선택 오류. Git Bash에서 재실행
- 활성화 전(`engsys` PATH 미등록): `sh`로 호출

```sh
cd /d/dev/engineering-system && sh install.sh
```

- 경로 형식: `D:\work\myapp` 대신 `/d/work/myapp`
- 줄바꿈: `.gitattributes`로 LF 고정
  - Git for Windows 기본값(`core.autocrlf=true`)으로 CRLF checkout 시 sh 파서가 값 끝 CR을 값 일부로 해석
  - 증상: `invalid profile name: 'baseline'` 같은 엉뚱한 오류
  - 조치: 오류가 가리키는 파일을 편집기에서 **LF**로 변환·저장 후 재검사. 내용 유지, 저장소 전체 초기화 불필요

---

아래 절: `setup`이 부르는 명령별 설명. 익숙하면 직접 사용 가능.

## 활성화

- 대상: clone 후 팀원 각자 한 번
- 변경 범위: 개발자 shell profile, 이 clone의 Git hook 경로. 프로젝트 쓰기 없음

```sh
git clone https://github.com/pis-o-cake/engineering-system
cd engineering-system && ./install.sh     # Windows: sh install.sh (Git Bash)
```

- `--print`: profile에 넣을 줄만 출력
- profile에 다른 checkout을 가리키는 줄 존재 시: 덮지 않고 그 줄 안내
- 상태 확인: `engsys doctor`
  - 보고 항목: PATH 연결, locked revision fetch 가능 여부, `engsys check` 통과 여부, origin/main 신규 revision 여부
  - 항목별 실행 명령 안내

```sh
engsys doctor --project /path/to/project
```

## 표준 버전 올리기

- 배포 채널: `origin/main`
- lock 기록값: 명령 실행자의 system checkout revision → 올리기 전 checkout을 원하는 지점에 배치
- 특정 release 고정: 해당 tag checkout

```sh
git -C /path/to/engineering-system checkout main && git -C /path/to/engineering-system pull
engsys upgrade --project /path/to/project            # plan만 출력
engsys upgrade --project /path/to/project --apply
```

- 프로젝트 검사 명령(`check`·`sync`·`verify`·`docs`·`review`·`vcs`): **프로젝트가 lock한 revision에서 실행**
  - PATH의 `engsys`: 실행기. 판정 코드 출처: lock이 가리키는 release
  - 같은 revision checkout에 미커밋 수정이 있어도 clean cache에서 실행
  - lock revision 준비 실패·cache 수정 감지 → 현재 checkout 대체 없이 실패
  - 미대상: `init`·`upgrade`·`doctor`
  - 자기 레포 검사: 현재 코드 사용. 다른 프로젝트에서 표준 수정 시험: `ENGSYS_USE_CHECKOUT=1` 명시
    ([ADR 0019](docs/adr/0019-verification-fails-when-it-cannot-run.md))
- `engsys verify --revision <commit>`
  - working tree와 해당 commit 일치 여부 선확인. 불일치 시 차이 출력 후 중단
  - 기본 `pre-push`가 이 형태로 호출 → 검사 내용 = 전송 내용일 때만 통과
  - 다른 내용의 ref push: 해당 commit checkout 후 재실행
  - `engsys` PATH 부재로 검사 시작 불가 시에도 push 중단
    ([ADR 0019](docs/adr/0019-verification-fails-when-it-cannot-run.md))
- `--apply`: 새 lock으로 native test·generated document check 실행, 실패 시 이전 lock 복원
- `doctor` 경고: lock이 아직 `origin/main`에 없을 때. 그 상태로 push 시 팀원 clone이 해당 revision fetch 불가

## 프로젝트 채택

- 대상 Git 프로젝트: dependency 설치 없이 adapter만 생성
- `init`: 기존 계약 덮어쓰기 없음
- manifest 수동 변경 후: `sync` → `check` 순서 실행

```sh
engsys init --project /path/to/project --detect --hooks
engsys verify --project /path/to/project
```

- `--dry-run`: 쓸 내용만 표시, 변경 없음
- `--detect`: 미설정 선언만 프로젝트에서 읽어 채움, 채운 값 전부 출력
  - 대상: native 검증 명령, source-of-truth 디렉토리, 문서 정본 경로, lifecycle, 문서가 아직 없는 경로의 유형 배정
  - 문서가 이미 있는 경로: 배정 없이 경로만 안내. 이유: 유형 미선언 문서 배정 시 채택 첫날 검사 전부 실패
  - 명시 옵션이 감지보다 항상 우선
  - 감지 범위: 최상위 디렉토리만. `backend/pyproject.toml`처럼 한 단계 아래 스택은 미감지 → `--verify 'cd backend && poe check'`처럼 직접 지정
- 복사한 hook: 프로젝트 소유, 표준이 덮어쓰지 않음. template 변경 여부는 `engsys hooks status`가 알림

```sh
engsys hooks status --project /path/to/project
engsys hooks update --project /path/to/project           # 고치지 않은 사본만 갱신
engsys hooks update --project /path/to/project --adopt   # 사본 유지, 확인만 기록
```

- 고친 사본: `--force` 없이는 변경 없음
- 기록 위치: `.engsys/hooks.txt`, 프로젝트가 commit
  ([ADR 0015](docs/adr/0015-hook-copies-are-diagnosed-not-overwritten.md))
- `--hooks`: `pre-push` gate를 프로젝트에 복사, `core.hooksPath`가 비어 있을 때만 등록. 파일은 프로젝트 소유, 이후 표준이 덮어쓰지 않음
  ([ADR 0008](docs/adr/0008-init-detects-declarations-and-seeds-the-project-gate.md))

### `engsys check`가 보는 것과 보지 못하는 것

- 읽는 방식: dependency 없이 sed·awk
- 지원 문법: 2칸 들여쓰기 mapping·sequence, single-quoted scalar, `[a, b]` 형태 inline list. 그 외 미해석
- 검사 대상
  - 최상위 key 집합, 필수 항목 존재
  - **선언한 block의 실제 해석 여부** — `documentation.authoring`·`documentation.review`·`documentation.lifecycle`·`vcs.branch` 선언 후 항목 0건이면 오류. 들여쓰기 오류 계약이 0건으로 조용히 통과하던 경로 차단
- 미검사: 값 형식, 중첩 구조 전체
  - 계약 형식 정본: [project schema](schemas/project.schema.json). 전체 검증은 시스템 레포 test 담당
    ([ADR 0002](docs/adr/0002-contract-schema-is-canonical.md))
- 역할 구분
  - `check`: adapter·lock 빠른 검사
  - `verify`: 이후 프로젝트 선언 native test·generated document check 실행
- profile 변경·package 추가: 기존 lock 불변. 반영은 위 「표준 버전 올리기」의 `upgrade` 담당

### OS마다 명령이 갈릴 때

- `npm test`·`go test ./...`·`cargo test`·`./gradlew check`: OS 무관 동일 문자열 → 한 줄로 충분
- 변형 선언: Python venv처럼 실행 경로가 갈릴 때만

```yaml
commands:
  verify: 'cd backend && .venv/bin/poe check'          # macOS·Linux
  verify-windows: 'cd backend && .venv/Scripts/poe check'
```

- 선택 방식: `engsys verify`가 `uname`으로 판정. 양쪽 머신 입력 명령 동일
- 선택 키 출력 — `Running project verification (commands.verify-windows): ...`
- 접미사: `-macos`·`-linux`·`-windows`만. 접미사 없는 기본 선언은 계속 필수
- `documentation.generated[].command`도 같은 방식으로 `command-windows` 지원
- `documentation.generated` 해석
  - `output`·`command` 순서 무관
  - 각 항목: 두 값을 모두 가진 block mapping 필수
  - 미지원 inline mapping·multiline scalar → 오류
  - quote·escape 필요 시 single-quoted scalar 사용

### Claude Code 연결 경로

- 기본: 프로젝트 `.claude/settings.json`의 marketplace 선언
  - commit 대상 → 세션을 어떻게 열든 동일 부착
  - skill·hook 배선 출처: 표준의 `main`
- `engsys claude`: **재현 모드**. 일상 작업 기본 경로 아님
  - 용도: 옛 lock에 묶인 프로젝트를 당시 안내로 재확인, 표준 자체 수정
  - 동작: lock revision의 clean system worktree 선택 → lock 내 package만 developer-local cache plugin view로 조합
  - 결과: 선택하지 않은 skill·hook은 Claude에 미등록
- 공통: **판정 고정**
  - hook은 `engsys` 호출, `engsys`는 자신을 lock revision으로 재실행
  - marketplace 경로에서 흔들리는 것: 안내문. 합격 여부는 불변
    ([ADR 0023](docs/adr/0023-the-standard-ships-as-a-plugin-marketplace.md))
- `ENGSYS_PLUGIN_ROOT`: launcher가 plugin view 경로를 export. skill은 이 변수로만 plugin 내부 스크립트 실행
- `CLAUDE_PLUGIN_ROOT`: hook process 전용, skill에서는 빈 값
  ([ADR 0003](docs/adr/0003-skill-uses-launcher-environment.md))

## 시스템 레포 개발

- 이 레포 수정 시에만 필요한 전제: `tools/` 검사·생성 도구의 python3 표준 라이브러리
- 표준 채택 프로젝트: 해당 전제 없음
  ([ADR 0001](docs/adr/0001-posix-sh-core-with-python-tooling.md))

```sh
sh tests/test-all.sh          # 전체 검사 (이 레포의 commands.verify)
bin/engsys verify --project . # 계약 검사 + 위 test + 생성 문서 최신 여부
```

- 서버 CI: 아직 없음
- push 전 검사 강제: `.githooks/pre-push`
  - 삭제 제외 전송 ref마다 `bin/engsys verify --project . --revision <commit>` 실행 → 검사 내용 = 전송 내용일 때만 통과
  - 등록: `install.sh`. 등록 여부 보고: `engsys doctor`
- 한계: 로컬 hook은 사람이 우회 가능. 서버 검사 전까지 통과 = push한 개발자 환경 결과, 다른 OS 동작 보증 없음
- self lock 신선도 확인: native 검사에 포함
  - `packages/`·`bin/`·`lib/` 변경 commit 후 `bin/engsys upgrade --project . --apply`로 자기 lock 갱신, lock 변경 commit
  - 미갱신 시 `engsys claude`가 병합 전 revision의 skill·hook 조합
- `docs/generated/`: 수동 편집 금지. `python3 tools/generate-catalog.py`로 재생성
- `python3 tools/check-documentation.py`: native 검사 포함
  - 검사: `.engsys/` 선언 historical 문서의 필수 frontmatter, policy status 목록, local link 대상 존재
  - 미검사: 본문과 현행 코드 비교, 외부 URL, heading fragment
  - 다른 프로젝트 문서 검사: 그 프로젝트 native command 담당

## 커밋과 merge request 규약

- 정본: [commit contract](packages/vcs-gov/commit-contract.yaml) — 커밋 헤더 포맷, type 목록, subject 길이, 금지 trailer, MR 본문 필수 절
- 프로젝트 선언: `.engsys/project.yaml`의 `vcs` 블록에 값만 — subject 언어·종결 어미, `scope` 목록, branch model, MR 대상 branch

```sh
engsys vcs check-message .git/COMMIT_EDITMSG --project .
```

- 같은 검사: `engsys init --hooks`가 심는 `commit-msg` hook
- 강제 주체: native git hook. 이유: 커밋은 세션 밖에서도 발생 → Claude Code hook으로는 불충분
- 작성 보조: `/engsys:write-commit`·`/engsys:write-merge-request`
- MR 본문: git 밖이라 git hook 지점 없음 → 본문을 파일로 작성 후 판정

```sh
engsys vcs check-merge-request pr-body.md --title 'fix(auth): 로그인 게이트 추가' --project .
gh pr create --title 'fix(auth): 로그인 게이트 추가' --body-file pr-body.md
```

- `gh pr create` 앞 판정 호출: plugin이 등록한 hook. 읽을 수 없는 inline `--body` 차단
- **강제 근거: 세션이 읽은 skill이 아니라 저장소에 든 선언** — `init`이 남긴 `.claude/settings.json`이 plugin 부착, plugin이 gate 운반
  ([ADR 0022](docs/adr/0022-a-declared-contract-needs-a-gate-not-an-instruction.md) ·
  [ADR 0025](docs/adr/0025-the-gate-travels-with-the-plugin-not-the-path.md))
- hook의 `engsys` 탐색 순서: `ENGSYS_SYSTEM_ROOT` → `CLAUDE_PLUGIN_ROOT` → PATH. 로그인 셸 밖 실행 사례 존재 → PATH만 의존 시 gate가 꺼진 채 동작
- 판정 범위: 절 제목·순서, 선언 밖 제목, 빈 절, 금지 문구, title 형식
- 리뷰어 몫: 문체, 중복 서술

### branch model

- 정의 범위: 역할, 분기·승격 방향만. 실제 이름은 프로젝트 결정

```yaml
vcs:
  branch:
    model: 'env-branch'
    roles:                    # 선언 순서 = 승격 순서
      - role: 'development'
        branch: 'develop'
      - role: 'production'
        branch: 'main'
    prefixes:
      feature: 'feat/'
      hotfix: 'hotfix/'
```

- **표준은 branch 이름 미보유**
  - 미선언 시 `engsys vcs check-settings`가 선언할 항목 안내, `base-branch`는 응답 없음
  - hotfix 분기: `prefixes.hotfix` 선언 시에만
    ([ADR 0017](docs/adr/0017-the-standard-holds-no-branch-names.md))
- `engsys vcs base-branch`: 분기 기준 응답. `engsys vcs settings`: 해석된 값 표시
- hook·skill: 위 명령 사용, branch 이름 직접 기재 없음
- 잘못된 선언: `engsys verify`의 `check-settings`가 검출
- 적용 범위: 로컬 규칙. **Git 서버 protected branch 설정은 미적용**
- branch 이름 규칙
  - 기본값: model의 `naming`. 프로젝트가 `vcs.branch.naming`에 pattern 선언 시 그것이 우선
  - 판정: 선언 시에만 `engsys vcs check-branch`, push gate가 호출
  - 제외: protected branch, detached HEAD
- 차단 기준: 기계 판정 가능 항목만. `·` 나열처럼 커밋 분할 신호는 경고 후 통과
  ([ADR 0011](docs/adr/0011-vcs-gov-owns-the-commit-and-merge-request-contract.md))

## 닫지 못한 것

- 이번 변경에서 닫지 못한 것: 담당자·종료 조건을 가진 추적 항목에 연결. 문서에서 상태 재관리 없음
- 표준 보유: [tracker contract](packages/vcs-gov/tracker-contract.yaml) — 항목 종류, 종료 조건 성격, 필수 정보, 중복 확인, 등록 시점, 종료 증거
- 프로젝트 선언: 사용할 도구, label

```yaml
vcs:
  tracker:
    provider: 'gitlab'              # github 또는 gitlab
    project: 'group/thing'
    default-assignee: 'someone'
    labels:
      defect: '결함'
    agent:                          # allowed 또는 ask
      create: 'allowed'
      close: 'ask'
```

- **표준은 tracker 이름·label 이름 미보유**. 미선언 시 `engsys vcs tracker` 응답 없음
- 선언 판정: `engsys vcs check-tracker`
- `accept-risk`·`commit-deadline`: 계약상 사람 고정 → `allowed` 불가
  ([ADR 0024](docs/adr/0024-the-project-declares-its-tracker-and-agent-permissions.md))
- MR 본문 「영향 및 후속 작업」에 후속 표현이 있는데 추적 항목 링크 없음 → gate 차단
  - 판정 대상: 링크 형식만, 항목 내용은 미확인
  - 남은 것 없음: 「없음」 기재
- 등록·중복 확인·근거 갱신: `/engsys:track-unresolved`가 한 흐름으로 처리

## 문서 유형과 구조 검사

- 새 문서: 유형 선결정
- 정본: [document types](packages/docs-gov/document-types.yaml) — 유형별 독자, 답할 질문, 필수 metadata, 필수 절
- 경로별 유형 배정: `.engsys/project.yaml`의 `documentation.authoring`
- 작성 전 계약 확인 절차: `/engsys:write-document`

```sh
engsys docs new --type decision-record --project . cache-strategy
engsys docs check --project .
```

- `docs new`: 배정 경로에 metadata·필수 절 제목 생성, 유형 형식대로 번호·날짜 부여
- **절 내용은 미생성 → 생성 직후 파일은 검사 불통과**. 뼈대는 타이핑 절감용, 글은 작성자 몫
  ([ADR 0016](docs/adr/0016-a-scaffold-fills-the-form-not-the-writing.md))
- `--path <문서>`: 해당 문서 하나만 검사. 미배정 경로·없는 파일은 오류 아님
- plugin 부착 세션: 자동 검사
  - 문서 작성 직후 그 문서 하나 검사, 실패 결과를 Claude에 전달해 즉시 수정
  - 세션 시작 시 검토 기록 없는 문서 수 한 줄 주입
  - 사람이 에디터로 직접 고친 문서: 이 층 미적용, push gate가 검출
    ([ADR 0009](docs/adr/0009-document-structure-feedback-at-write-time.md))
- 출력: 배정 문서 수·findings 외에 **절 검사 유예·검사 제외·유형 미배정** 규모 동시 표시
  - 이유: 통과 여부만으로는 검사 밖 범위 파악 불가
  - 미배정 문서: 경로 최대 다섯 개 출력
- 검사 항목: 유형, status, 필수 metadata, 근거 경로, 도입 문단, 필수 절
  - `frozen-status` 해당 기록: 절 존재만 확인, 순서 미강제
  - `deferred` 선언 경로: 절 검사 유예, metadata만 검사
  - 문체 판정 없음
    ([ADR 0006](docs/adr/0006-document-type-contract-in-posix-sh.md))

## 문서 편집 검토

- 대상: 보고·운영·설계 문서. [편집 기준](packages/docs-gov/editorial.md)에 따라 한 편씩 읽고 수정
- 절차: `/engsys:review-document` — 최종본 검토, 문서별 기록 생성
- 기록 내용: 본문 해시, 검토자, 독자, 문서가 답할 질문, 구체적 검토 내용

```sh
engsys review status
engsys review record --document docs/report.md --blob <검토한-본문-해시> \
  --reviewer <실제-검토자> --audience <독자> --purpose <답할-질문> --notes-file <검토-메모>
engsys review check
```

- 검사 범위 정본: 계약의 `documentation.review.scopes`
  - `--scope` 생략 시 이 목록 사용 → 프로젝트 hook의 중복 파싱 불필요
- 프로젝트 연결: `engsys review check`를 native 검사에 포함
- 판정
  - 생성 문서: 제외
  - 새 문서·검토 후 변경 문서: 실패
  - 기존 문서를 범위에 추가할 때도 최초 개별 검토 필요
- commit 단위: 문서 + `.engsys/reviews/`의 해당 기록 함께
- 전체 문체 자동 판정·일괄 승인 없음
- push gate: `engsys review check --revision <전송할-commit>`
  - 전송할 본문·기록 동시 검사. 범위·생성 문서 목록도 그 commit의 계약에서 해석
  - 이 레포 연결 위치: `.githooks/pre-push`
- 한계: 검토 기록의 존재·신선도만 확인. 글의 품질·상급자 승인 증명 아님
