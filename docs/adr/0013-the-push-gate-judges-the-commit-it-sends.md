---
type: adr
id: 0013
status: accepted
date: 2026-09-09
---

# 0013. push gate 는 전송할 commit 을 판정한다

`engsys verify --revision <commit>` 은 검사 대상이 그 commit 과 같은지 먼저 단언한 뒤 검사한다.
기본 `pre-push` 는 이 형태로 부른다. 이전에는 working tree 를 검사하고 다른 commit 을 통과시켰다.

## 결정

- `engsys verify --revision <commit>` 은 working tree 가 그 commit 과 같은지 먼저 확인한다. tracked
  차이나 untracked 파일이 있으면 무엇이 다른지 출력하고 중단한다.
- `verify` 는 매번 실행한 표준 revision 을 출력한다. `--revision` 을 준 실행은 판정한 commit 도
  함께 출력한다.
- 기본 `pre-push` 는 전송할 ref 마다 그 commit 으로 `verify` 를 부른다. checkout 한 commit 이 아닌
  ref 는 검사하지 않았다고 알린다. 하나의 working tree 는 하나의 commit 과만 같을 수 있다.
- `--revision` 이 있는 실행에서 lock revision 을 받지 못하면 중단한다. 그 인자가 없는 탐색용
  실행에서만 현재 checkout 으로 대체한다.

## 배경과 제약

`pre-push` 는 `engsys verify` 를 working tree 에 대해 실행했고, 전송할 commit 을 보는 것은 편집 검토
기록 검사뿐이었다. 그래서 commit 에는 실패할 내용이 있고 working tree 에는 고친 내용이 있으면
gate 가 통과했다. 임시 프로젝트에서 재현했다 — commit 의 값 `bad`, working tree 의 값 `good`,
`pre-push` 결과 `exit 0`.

[ADR 0012](0012-project-commands-run-at-the-locked-revision.md)로 검사기의 revision 을 고정했지만
검사 대상은 고정하지 않은 상태였다.

제약이 하나 있다. `commands.verify` 와 생성 문서 명령은 개발 환경에 의존한다. `public-ai-qa` 의
검사 명령은 `.venv` 를 쓰고, 그 디렉토리는 commit 에 없다. 임의 commit 을 깨끗한 worktree 로 꺼내
실행하는 방법은 이 제약 때문에 쓸 수 없다.

## 근거와 대안

- **전송할 commit 을 임시 worktree 로 꺼내 검사한다**: 가장 정확하지만 `.venv` · `node_modules`
  처럼 commit 에 없는 도구가 필요한 검사가 실행되지 않는다. 그 환경을 준비하는 것은 CI 의 일이다.
- **working tree 가 깨끗할 때만 push 를 허용한다**: 결과는 같지만 이유를 알려 주지 않는다. 무엇이
  다른지 보여 주고 중단하는 쪽이 고치기 쉽다.
- **차이를 경고만 하고 통과시킨다**: 지금과 같다. gate 가 거짓 통과를 내면 gate 가 없는 것보다
  나쁘다. 없으면 사람이 직접 확인하지만, 있으면 확인했다고 믿는다.
- **모든 ref 를 검사한다**: 하나의 working tree 는 하나의 commit 과만 같다. 검사하지 못한 ref 는
  검사했다고 적지 않고 그 사실을 알린다.

## 영향

- push 하기 전에 변경을 commit 하거나 stash 해야 한다. 문서를 고치다 push 하던 흐름이 한 단계
  늘어난다. `--no-verify` 는 그대로 남는다.
- `--revision` 없이 부른 `verify` 의 뜻은 달라지지 않는다. working tree 를 검사하며, 그것이 개발
  중에 필요한 실행이다.
- gate 경로에서 lock revision 을 받지 못하면 중단한다. 오프라인에서 push 하려면 그 revision 을 먼저
  받아 두어야 한다.
- 여러 ref 를 한 번에 push 하면 checkout 한 것 하나만 검사한다. 나머지는 CI 가 볼 몫이다.
