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

현재 package는 `foundation`, `docs-gov`, `vcs-gov`, `pipeline`이다. 이 레포 자신이 첫 pilot이며,
`.engsys/`로 자기 표준을 채택하고 있다.

- [Current architecture](docs/architecture/README.md) — 지금 어떻게 되어 있는가
- [Architecture Decision Record](docs/adr) — 그 뒤로 왜 바뀌었는가
- [Foundation design](docs/design/0001-foundation.md) — 그때 왜 이렇게 설계했는가
- [System catalog](docs/generated/system-catalog.md) — 선언에서 생성되는 package·skill 목록
- [Project contract schema](schemas/project.schema.json)
- [Project lock schema](schemas/lock.schema.json)
- [Baseline profile](profiles/baseline.yaml)
- [Bootstrap workflow](workflows/bootstrap.yaml)
- [Adoption evaluation](docs/verification/adoption.md) — 효과와 실행 비용을 판단하는 기준

## 처음 붙일 때

표준은 한 번 clone해 두고, 붙일 프로젝트마다 계약 파일 두 개로 사용할 표준과 버전을 선언한다.
아래 setup이 계약 생성과 프로젝트의 Git hook 연결을 안내한다.

### 1. 표준을 clone 하고 활성화한다 — 이 컴퓨터에서 한 번

```sh
git clone https://github.com/pis-o-cake/engineering-system
cd engineering-system
./install.sh
```

`install.sh` 가 바꾸는 것은 둘이다. shell profile(`~/.zshrc` 등)에 `engsys` 를 PATH 에 넣는 한 줄을
추가하고, 이 clone 의 Git hook 경로를 설정한다. 다른 프로젝트는 건드리지 않는다. 되돌리려면 그
줄을 지운다.

끝나면 **새 터미널을 연다.** 그래야 `engsys` 가 잡힌다.

### 2. 붙일 프로젝트에서 setup 을 실행한다 — 프로젝트마다 한 번

```sh
cd /내/프로젝트
engsys setup
```

경로를 적을 필요가 없다. 현재 디렉토리가 대상이다.

`setup` 은 여덟 단계를 차례로 밟는다.

| 단계 | 하는 일 |
|---|---|
| 1. 전제 도구 | `git` 이 있는지 본다. `python3` 와 Claude Code 는 없어도 되고, 없으면 무엇이 안 되는지 알려 준다 |
| 2. 시스템 checkout | 표준이 어느 revision 인지, 팀원이 받을 수 있는 상태인지 확인한다 |
| 3. 개발자 활성화 | `engsys` 가 PATH 에 있는지 본다. 없으면 `install.sh` 를 실행할지 묻는다 |
| 4. 대상 프로젝트 | 프로젝트를 훑어 검사 명령·소스 경로·branch 이름을 **감지하고, 만들 계약 전문을 먼저 보여 준 뒤** 만들지 묻는다 |
| 5. Git hook | `commit-msg` 와 `pre-push` 를 심을지 묻고, `core.hooksPath` 가 없으면 세울지 묻는다. 이미 고쳐 쓰던 hook 이 있으면 덮지 않는다 |
| 6. 검사 | 계약이 올바른지 확인하고, 프로젝트의 기존 test 까지 돌릴지 묻는다 |
| 7. 최종 진단 | `doctor` 를 한 번 더 돌린다. 남은 문제가 있으면 성공으로 끝내지 않는다 |
| 8. 남은 것 | 아직 선언하지 않은 것과 commit 할 파일을 알려 준다 |

**파일을 바꾸기 전에는 반드시 먼저 보여 주고 묻는다.** 그냥 진행하려면 `--yes` 를 준다. 반대로
터미널이 없고 `--yes` 도 없으면 시작하지 않는다 — 물어볼 수 없는데 진행하면 아무것도 안 하고
성공한 것처럼 끝나기 때문이다.

### 3. 만들어진 파일을 commit 한다

```sh
git add .engsys .githooks .claude
git commit -m "build(engsys): Engineering System 계약 추가"
```

이 파일들이 있어야 팀원이 같은 계약을 받는다.

### 팀원은 무엇을 하나

`.claude/settings.json` 에 표준이 marketplace 로 선언돼 있으므로, 팀원이 프로젝트를 Claude Code 로
열면 skill 과 문서 guardrail 이 **자동으로 붙는다.** CLI 든 데스크톱 앱이든 IDE 확장이든 같다.
`engsys claude` 를 알 필요가 없다 ([ADR 0023](docs/adr/0023-the-standard-ships-as-a-plugin-marketplace.md)).

**단, plugin 은 판정하는 코드를 나르지 않는다.** 붙는 것은 skill 과 hook 배선이고, 그 hook 이
하는 일은 PATH 의 `engsys` 를 부르는 것이다. `engsys` 가 없으면 붙어 있어도 아무것도 판정하지
않는다. `engsys doctor` 가 이 상태를 실패로 보고한다.

그래서 나머지 둘은 각자 한 번씩 해야 한다.

```sh
git clone https://github.com/pis-o-cake/engineering-system && cd engineering-system && ./install.sh
cd /내/프로젝트 && engsys setup
```

- **`install.sh`** — 판정하는 코드(`engsys`)는 plugin 이 나르지 않는다. 각 머신에 있어야 한다.
- **`engsys setup`** — `core.hooksPath` 를 세운다. 이 설정은 `.git/config` 에 있어 **commit 되지
  않으므로** clone 만으로는 전달되지 않는다. 세우지 않으면 hook 파일이 있어도 Git 이 부르지 않는다.

둘 다 건너뛴 상태에서 push 하면 `pre-push` 가 원인을 알리고 막는다.

### 실패했을 때

`setup` 은 실패해도 아무것도 되돌리지 않는다. 멈춘 단계와 다음에 할 일을 마지막에 다시 적어 주고,
전체 출력을 파일로 남긴다. 터미널이 닫혀도 그 파일에 남아 있다.

```
멈춘 곳: [4] 대상 프로젝트
위의 마지막 오류 줄이 이유다. 아무것도 되돌리지 않았으니 고치고 다시 실행하면 된다.

  지금 상태 보기 : engsys doctor --project /내/프로젝트
  다시 실행      : engsys setup --project /내/프로젝트
  전체 기록      : /tmp/engsys-setup-4471.log
```

고친 뒤 `engsys setup` 을 다시 실행한다. 이미 끝난 단계는 그대로 통과한다.

### 상태 확인

```sh
engsys doctor      # 지금 무엇이 빠졌는지, 각각 어떤 명령으로 고치는지
engsys verify      # 계약·문서·프로젝트 test 를 전부 실행
```

`doctor` 는 진단만 하고 아무것도 고치지 않는다. 무엇을 실행할지 알려 주면 그것을 직접 실행한다.

### Windows

`engsys` 는 Git Bash 에서만 돈다. `bin/engsys` 는 확장자 없는 POSIX sh 라 PowerShell 과 CMD 는
그 파일을 실행하지 못하고, `install.sh` 도 bash 의 로그인 프로필만 고치므로 두 셸의 PATH 에는
아무것도 들어가지 않는다. 그래서 활성화를 마친 뒤에도 PowerShell 은 이렇게 답한다.

```
The term 'engsys' is not recognized as the name of a cmdlet, function, script file, ...
```

설치가 실패했다는 뜻이 아니라 셸을 잘못 열었다는 뜻이다. Git Bash 를 열고 다시 친다.

활성화 전이라 `engsys` 가 아직 PATH 에 없다면 `sh` 로 부른다.

```sh
cd /d/dev/engineering-system && sh install.sh
```

경로는 `D:\work\myapp` 이 아니라 `/d/work/myapp` 형식을 쓴다.

이 저장소는 `.gitattributes` 로 줄바꿈을 LF 로 고정한다. Git for Windows 의 기본값
(`core.autocrlf=true`)으로 CRLF 로 checkout 되면 sh 파서가 값 끝의 CR 을 값의 일부로 읽어
`invalid profile name: 'baseline'` 같은 엉뚱한 오류가 난다. 기존 checkout에서 이 문제가 나면
오류가 가리키는 파일을 편집기로 열어 줄바꿈을 **LF**로 바꾸고 저장한다. 파일 내용은 유지하고
줄바꿈만 변환한 뒤 다시 검사한다. 저장소 전체를 초기화할 필요는 없다.

---

아래 절들은 `setup` 이 부르는 명령을 하나씩 설명한다. 이미 익숙하면 직접 써도 된다.

## 활성화

팀원은 이 레포를 clone한 뒤 한 번만 실행한다. 개발자 자신의 shell profile과 이 clone의 Git hook
경로만 바꾸며, 프로젝트에는 아무것도 쓰지 않는다.

```sh
git clone https://github.com/pis-o-cake/engineering-system
cd engineering-system && ./install.sh     # Windows: sh install.sh (Git Bash)
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
온다. 같은 revision의 checkout에 미커밋 수정이 있어도 clean cache에서 실행한다.
lock revision을 준비하지 못하거나 cache가 수정돼 있으면 현재 checkout으로 대체하지 않고 실패한다.
`init`·`upgrade`·`doctor`는 넘기지 않는다. 자기 레포 검사는 현재 코드를 쓰며, 다른 프로젝트에서
표준 수정을 시험할 때는 `ENGSYS_USE_CHECKOUT=1`을 명시한다
([ADR 0019](docs/adr/0019-verification-fails-when-it-cannot-run.md)).

`engsys verify --revision <commit>`은 working tree가 그 commit과 같은지 먼저 확인하고 다르면
무엇이 다른지 출력한 뒤 중단한다. 기본 `pre-push`가 이 형태로 부르므로, gate는 검사한 내용과
전송하는 내용이 같을 때만 통과한다. 다른 내용을 가진 ref를 push하려면 해당 commit을 checkout하고
다시 실행한다. `engsys`가 PATH에 없어 검사를 시작할 수 없어도 push를 중단한다
([ADR 0019](docs/adr/0019-verification-fails-when-it-cannot-run.md)).

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

`--dry-run`을 주면 무엇을 쓸지 보여 주고 아무것도 바꾸지 않는다.

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

### `engsys check`가 보는 것과 보지 못하는 것

`check`는 dependency 없이 돌아야 하므로 계약을 sed·awk로 읽는다. 지원하는 문법은 2칸 들여쓰기
mapping과 sequence, single-quoted scalar, `[a, b]` 형태의 inline list다. 그 밖의 문법은 읽지 않는다.

검사하는 것은 최상위 key 집합, 필수 항목의 존재, 그리고 **선언한 block이 실제로 읽혔는지**다.
`documentation.authoring`·`documentation.review`·`documentation.lifecycle`·`vcs.branch`를 선언했는데
항목이 하나도 읽히지 않으면 오류로 끝난다. 들여쓰기를 잘못 쓴 계약이 0건으로 조용히 통과하던
경로다.

검사하지 않는 것은 값의 형식과 중첩 구조 전체다. 계약 형식의 정본은
[project schema](schemas/project.schema.json)이고, 그 전체 검증은 시스템 레포의 test가 한다
([ADR 0002](docs/adr/0002-contract-schema-is-canonical.md)).

`check`는 adapter와 lock만 빠르게 검사한다. `verify`는 그 뒤 project가 선언한 native test와
generated document check를 실행한다. profile 변경과 package 추가는 기존 lock을 바꾸지 않는다 —
반영은 위 "표준 버전 올리기"의 `upgrade`가 맡는다.

### OS 마다 명령이 갈릴 때

`npm test`·`go test ./...`·`cargo test`·`./gradlew check`는 어느 OS에서나 같은 문자열이므로 한 줄로
끝난다. Python venv처럼 실행 경로가 갈리는 경우에만 변형을 선언한다.

```yaml
commands:
  verify: 'cd backend && .venv/bin/poe check'          # macOS·Linux
  verify-windows: 'cd backend && .venv/Scripts/poe check'
```

`engsys verify`가 `uname`으로 판정해 알아서 고른다. 양쪽 머신에서 치는 명령은 똑같고, 고른 키는
출력에 찍힌다 — `Running project verification (commands.verify-windows): ...`. 접미사는
`-macos`·`-linux`·`-windows`뿐이며, 접미사 없는 기본 선언은 그대로 필수다.
`documentation.generated[].command`도 같은 방식으로 `command-windows`를 갖는다.

`documentation.generated`는 `output`과 `command`의 순서에 관계없이 읽는다. 각 항목은 두 값을
모두 가진 block mapping이어야 한다. 지원하지 않는 inline mapping·multiline scalar는 오류로
처리한다. 명령에 quote나 escape가 필요하면 single-quoted scalar를 쓴다.

Claude Code에 표준을 붙이는 길은 둘이다. 기본은 프로젝트의 `.claude/settings.json`이 표준을
marketplace로 선언하는 것이고, 이 파일은 commit되므로 세션을 어떻게 열든 같게 붙는다. 이때
skill과 hook 배선은 표준의 `main`에서 온다.

`engsys claude`는 **재현 모드**다. 옛 lock에 묶인 프로젝트를 그때의 안내로 다시 보거나 표준
자체를 고칠 때 쓴다. 일상 작업의 기본 경로가 아니다. launcher가 lock revision의
clean system worktree를 고른 뒤, lock에 있는 package만 developer-local cache plugin view로
조합한다. 따라서 선택하지 않은 skill·hook은 Claude에 등록되지 않는다.

어느 쪽이든 **판정은 고정된다.** hook이 하는 일은 `engsys`를 부르는 것이고, `engsys`는 자기를
lock revision으로 다시 실행하기 때문이다. marketplace 경로에서 흔들리는 것은 안내문이지 합격
여부가 아니다 ([ADR 0023](docs/adr/0023-the-standard-ships-as-a-plugin-marketplace.md)).

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

서버 CI는 아직 없다. push 전 검사는 `.githooks/pre-push`가 강제한다. 삭제를 뺀 전송 ref마다
`bin/engsys verify --project . --revision <commit>`을 실행하므로 검사한 내용과 전송하는 내용이
같을 때만 통과한다. 등록은 `install.sh`가 하며 등록 여부는 `engsys doctor`가 보고한다.

로컬 hook은 사람이 우회할 수 있다. 서버 검사가 생기기 전까지 통과는 push한 개발자의 환경에서
얻은 결과이며 다른 OS의 동작을 보증하지 않는다.

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

MR 본문은 git 안에 없어서 git hook을 걸 지점이 없다. 대신 본문을 파일로 쓰고 판정한다.

```sh
engsys vcs check-merge-request pr-body.md --title 'fix(auth): 로그인 게이트 추가' --project .
gh pr create --title 'fix(auth): 로그인 게이트 추가' --body-file pr-body.md
```

`init`이 프로젝트에 남기는 `.claude/settings.json`이 `gh pr create` 앞에서 같은 판정을 부른다.
읽을 수 없는 inline `--body`는 막는다. **강제하는 것은 세션이 읽은 skill이 아니라 저장소에 든
이 설정이다** ([ADR 0022](docs/adr/0022-a-declared-contract-needs-a-gate-not-an-instruction.md)).
판정 범위는 절 제목과 순서, 선언 밖 제목, 빈 절, 금지 문구, title 형식이다. 문체와 중복 서술은
리뷰어가 본다.

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

**표준은 branch 이름을 갖지 않는다.** 선언하지 않으면 `engsys vcs check-settings`가 무엇을
선언해야 하는지 알리고, `base-branch`는 답하지 않는다. hotfix 분기는 `prefixes.hotfix`를 선언했을
때만 갈라진다 ([ADR 0017](docs/adr/0017-the-standard-holds-no-branch-names.md)).

`engsys vcs base-branch`가 분기 기준을 답하고 `engsys vcs settings`가 해석된 값을 보여 준다. hook과 skill은 이 명령을 쓰고
branch 이름을 직접 적지 않는다. 잘못된 선언은 `engsys verify`의 `check-settings`가 잡는다.

이 선언은 로컬 규칙이다. **Git 서버의 protected branch 설정은 여기서 적용되지 않는다.**

branch 이름 규칙은 model의 `naming`이 기본값이고, 프로젝트가 `vcs.branch.naming`에 pattern을
선언하면 그것이 이긴다. 선언했을 때만 `engsys vcs check-branch`가 판정하며 push gate가 그것을
부른다. protected branch와 detached HEAD는 대상이 아니다.

기계가 판정할 수 있는 것만 막는다. `·` 나열처럼 커밋을 쪼갤 신호는 경고로 남기고 통과시킨다
([ADR 0011](docs/adr/0011-vcs-gov-owns-the-commit-and-merge-request-contract.md)).

## 닫지 못한 것

이번 변경에서 닫지 못한 것은 담당자와 종료 조건을 가진 추적 항목에 연결한다. 문서는 그 상태를
다시 관리하지 않는다. 표준이 갖는 것은 [tracker contract](packages/vcs-gov/tracker-contract.yaml)
— 항목의 종류와 종료 조건의 성격, 필수 정보, 중복 확인, 등록 시점, 종료 증거 — 이고, 어느 도구에
어떤 label 로 쓸지는 프로젝트가 선언한다.

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

**표준은 tracker 이름도 label 이름도 갖지 않는다.** 선언하지 않으면 `engsys vcs tracker`는 답하지
않는다. `engsys vcs check-tracker`가 선언을 판정하며, `accept-risk`와 `commit-deadline`은 계약이
사람에게 고정하므로 `allowed`로 열 수 없다
([ADR 0024](docs/adr/0024-the-project-declares-its-tracker-and-agent-permissions.md)).

MR 본문의 「영향 및 후속 작업」에 후속을 뜻하는 표현이 있는데 추적 항목 링크가 없으면 gate가
막는다. 링크의 형식만 보고 항목의 내용은 보지 않는다. 남은 것이 없으면 「없음」으로 적는다.
등록·중복 확인·근거 갱신은 `/engsys:track-unresolved`가 한 흐름으로 처리한다.

## 문서 유형과 구조 검사

새 문서는 유형을 먼저 정한다. 유형별 독자, 답할 질문, 필수 metadata, 필수 절의 정본은
[document types](packages/docs-gov/document-types.yaml)이고, 프로젝트는 `.engsys/project.yaml`의
`documentation.authoring`에서 경로에 유형을 배정한다. `/engsys:write-document`가 작성 전에 그
계약을 읽는 절차를 제공한다.

```sh
engsys docs new --type decision-record --project . cache-strategy
engsys docs check --project .
```

`docs new`는 배정된 경로에 metadata와 필수 절 제목을 만든다. 번호와 날짜도 유형이 정한 형식으로
붙인다. **절의 내용은 만들지 않으므로 생성 직후의 파일은 검사를 통과하지 않는다** — 뼈대는
타이핑을 줄이고 글은 작성자가 쓴다
([ADR 0016](docs/adr/0016-a-scaffold-fills-the-form-not-the-writing.md)).

`--path <문서>`를 주면 그 문서 하나만 본다. 배정되지 않은 경로와 없는 파일은 오류가 아니다.

표준이 plugin으로 붙은 세션에서는 이 검사가 자동으로 돈다. 문서를 쓴 직후 그 문서 하나가 검사되고,
실패하면 결과가 Claude에게 전달돼 그 자리에서 고친다. 세션을 열 때는 검토 기록이 없는 문서 수가
한 줄로 주입된다. 사람이 에디터로 직접 고친 문서는 이 층에 걸리지 않으며 push gate가 잡는다
([ADR 0009](docs/adr/0009-document-structure-feedback-at-write-time.md)).

출력은 배정된 문서 수와 findings 외에 **절 검사 유예·검사 제외·유형 미배정**의 규모를 함께
보여 준다. 통과 여부만 보이면 무엇이 검사 밖에 있는지 알 수 없다. 미배정 문서는 경로도 최대
다섯 개까지 출력한다.

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
