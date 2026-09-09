---
type: adr
id: 0011
status: accepted
date: 2026-09-09
---

# 0011. 커밋·MR 규약은 vcs-gov가 갖고 프로젝트는 값만 선언한다

커밋 메시지 포맷과 MR 본문 구성을 `packages/vcs-gov`가 소유하고, 프로젝트는 subject 언어·종결
어미·scope 목록·branch model만 선언한다. 강제는 native `commit-msg` hook이 맡는다. 사람이
`git commit`을 직접 쳐도 걸려야 하기 때문이다.

## 결정

- `vcs-gov`가 커밋 헤더 포맷, type 목록, subject 길이 상한, 금지 trailer, 헤더 뒤 빈 줄, MR 본문
  필수 절, branch model 목록을 갖는다. 팀이 달라도 바뀌지 않는 것들이다.
- 프로젝트는 `.engsys/project.yaml`의 `vcs` 블록에 값만 선언한다 — `commit.subject-language`,
  `commit.subject-ending`, `commit.scopes`, `branch.model`, `branch.protected`,
  `merge-request.target`. 공통 규칙을 프로젝트에 복사하지 않는다.
- 강제는 native git hook이다. `engsys init --hooks`가 `commit-msg`와 `pre-push`를 함께 심고,
  검사는 `engsys vcs check-message`가 한다. Claude Code hook은 세션 안에서만 걸리므로 쓰지 않는다.
- 기계가 판정할 수 있는 것만 막는다. `·` 나열처럼 커밋을 쪼갤 신호는 경고로 남기고 통과시킨다.
- `imperative` 종결에는 기계 규칙을 두지 않는다. 판정은 skill과 사람이 한다.
- v0.1에서 native 검사가 있는 것은 커밋 메시지뿐이다. MR 본문과 branch model은 skill이 읽는
  계약으로 둔다.

## 배경과 제약

`public-ai-qa`는 커밋 규약을 `CLAUDE.md`에 적고 `.githooks/commit-msg` 110줄로 강제했다. 강제
장치가 없던 동안 쌓인 커밋 503개 중 금지된 `…것` 종결이 31건(6.2%), `·` 나열이 88건(17.5%)이었다.
규약이 있어도 검사가 없으면 지켜지지 않는다는 것이 그 레포에서 측정됐다.

그 훅은 프로젝트가 소유하므로 다음 프로젝트는 같은 파일을 다시 만들어야 한다. 훅의 오류 메시지가
그 레포의 `CLAUDE.md §2`를 인용하고 있어 그대로 옮길 수도 없다.

제약은 두 가지다. [ADR 0001](0001-posix-sh-core-with-python-tooling.md)의 POSIX sh 경계를 지킨다.
그리고 subject 길이는 글자 수로 세야 한다 — 한글은 UTF-8에서 3바이트라 C 로케일의 `wc -m`은
정상 메시지를 3배로 계산해 전부 막는다.

## 근거와 대안

- **Claude Code hook으로 배포한다**: 세션 안에서만 걸린다. 사람이 터미널에서 `git commit`을 치거나
  다른 도구가 커밋을 만들면 샌다. 커밋은 세션 밖에서도 생긴다.
- **skill만 둔다**: 작성은 도와주지만 강제가 없다. `docs-gov`의 `write-document` ↔ `docs check`와
  같은 이유로 둘 다 둔다. skill이 작성 시점을, hook이 커밋 시점을 맡는다.
- **subject 언어와 종결까지 시스템이 정한다**: 이 팀은 한국어 명사형이지만 영문 명령형 팀이 더
  많다. 그 값을 시스템에 두면 다른 팀이 채택할 수 없다. 포맷과 값의 경계를
  [ADR 0006](0006-document-type-contract-in-posix-sh.md)의 유형 계약과 같은 갈래로 나눴다.
- **`imperative`에도 접미사 규칙을 둔다**: 만들었다가 버렸다. `ed`·`ing`를 금지하면 `shared`로
  끝나는 정상 subject가 막힌다. 접미사로 English의 mood를 판정할 수 없다. 검증하지 못한 규칙을
  두면 규약이 아니라 훅을 피하게 된다.
- **`·` 나열을 막는다**: 형식 위반이 아니라 커밋을 쪼갤 신호다. 막으면 나열만 지우고 통과시킨다.
  경고는 신호를 전달하고 판단은 작성자에게 남긴다.

## 영향

- 새 프로젝트는 `engsys init --hooks` 한 번으로 커밋 규약을 얻는다. `scopes`를 선언하면 선언 밖의
  scope가 막히므로, scope 추가는 선언을 고치는 일이 된다.
- 프로젝트가 복사한 `commit-msg`는 그 프로젝트가 소유한다. 표준이 나중에 덮어쓰지 않는다.
- `engsys`가 PATH에 없으면 커밋을 막지 않고 그 사실을 알린다
  ([ADR 0008](0008-init-detects-declarations-and-seeds-the-project-gate.md)과 같은 이유).
- 이 레포도 채택했다. 선언 뒤 최근 커밋 20건을 검사해 전부 통과했다.
- MR 본문에는 native 검사가 없다. 규약을 어긴 MR을 기계가 잡지 못한다. 필요해지면 별도로 본다.
- branch 이름은 프로젝트가 `vcs.branch.naming`에 선언할 때만 검사한다. model의 `naming`은 기본값
  이고, 선언이 없으면 `engsys vcs check-branch`는 아무것도 판정하지 않는다. 정리되지 않은 목록을
  선언하면 채택 첫날부터 정상 branch가 막힌다.
- `public-ai-qa`는 자기 `commit-msg`와 그 테스트를 걷어내고 이 계약으로 옮길 수 있다. 이미 만든
  커밋을 다시 검사하지는 않는다.
