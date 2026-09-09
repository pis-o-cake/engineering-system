---
type: adr
id: 0012
status: accepted
date: 2026-09-09
---

# 0012. 프로젝트 명령은 lock 이 가리키는 revision 에서 실행한다

PATH 의 `engsys` 를 실행기로 두고, 프로젝트를 검사하는 코드는 그 프로젝트의 `lock.yaml` 이 가리키는
revision 에서 가져온다. 지금까지는 `engsys claude` 만 lock 을 봤고 나머지 명령은 실행한 개발자의
checkout 으로 돌았다.

## 결정

- `check` · `sync` · `verify` · `docs` · `review` · `vcs` 는 대상 프로젝트의 lock revision 으로
  실행을 넘긴다. 그 revision 의 worktree 는 `engsys claude` 가 쓰던 캐시를 그대로 쓴다.
- 넘기지 않는 명령이 넷 있다. `init` 은 lock 이 아직 없고, `upgrade` 는 lock 을 바꾸는 명령이라 새
  코드가 돌아야 하며, `doctor` 는 버전 차이 자체를 진단하고, `claude` 는 이미 lock 을 쓴다.
- lock revision 이 현재 checkout 의 commit 과 같으면 넘기지 않는다. working tree 의 수정은 revision
  을 바꾸지 않으므로, 표준을 고치는 중에도 자기 수정으로 검사할 수 있다.
- 대상이 시스템 레포 자신이면 넘기지 않는다. `ENGSYS_USE_CHECKOUT` 을 주면 어느 프로젝트에서도
  넘기지 않는다.
- lock revision 을 받을 수 없으면 작업을 막지 않는다. 그 사실을 알리고 현재 checkout 으로 실행한다.

## 배경과 제약

`.engsys/lock.yaml` 은 v0.1 부터 revision 을 고정했지만 그것을 읽는 것은 `engsys claude` 뿐이었다.
터미널에서 친 `engsys docs check` 와 Git hook 이 부른 `engsys vcs check-message` 는 실행한 사람의
checkout 으로 돌았다.

그래서 같은 프로젝트를 두 사람이 검사하면 결과가 다를 수 있었다. 실제로 이 표준을 개발하는 동안
`public-ai-qa` 의 문서 검사가 아직 병합되지 않은 branch 의 검사기로 돌았다. 그 결과는 lock 이 가리키는
표준의 판정이 아니다.

제약은 [ADR 0007](0007-one-command-activation-and-main-as-release-channel.md)이 정한 배포 경로다.
release 는 `origin/main` 의 commit 이고 프로젝트는 그중 하나를 lock 에 적는다. 그 commit 을 가져오는
방법은 이미 `resolve_locked_plugin` 에 있다.

## 근거와 대안

- **lock 을 읽지 않고 지금처럼 둔다**: 개발자마다 다른 결과를 얻는다. lock 이 있는데 대부분의 명령이
  그것을 무시하면 고정은 이름뿐이다.
- **모든 명령을 넘긴다**: `upgrade` 가 옛 revision 에서 돌면 자기 자신을 새 revision 으로 올릴 수 없다.
  `doctor` 는 checkout 과 lock 의 차이를 보고하는 명령이라 넘기면 그 차이를 볼 수 없다.
- **working tree 가 더러우면 넘긴다**: `resolve_locked_plugin` 은 원래 그렇게 판정한다. 그러나 그러면
  표준을 고치는 사람이 자기 수정으로 검사할 수 없다. revision 이 같으면 넘기지 않는 쪽을 택했다.
- **받을 수 없는 revision 에서 멈춘다**: 네트워크가 없거나 revision 이 push 되지 않은 상태에서 모든
  검사가 멈춘다. 막힌 이유를 설명하지 못하는 gate 는 삭제된다
  ([ADR 0008](0008-init-detects-declarations-and-seeds-the-project-gate.md)과 같은 판단). 알리고 진행한다.

## 영향

- 팀원이 어느 branch 를 checkout 해 두었든 프로젝트 검사 결과가 같아진다. 표준 버전을 올리는 길은
  `engsys upgrade --apply` 하나가 된다.
- 옛 revision 에 고정된 프로젝트에서는 그 revision 에 없는 명령이 `unknown command` 로 끝난다. 그
  프로젝트가 그 규약을 아직 채택하지 않았다는 뜻이므로 정확한 동작이다. 프로젝트 Git hook 은 그
  경우를 이미 통과시킨다.
- 첫 실행에서 lock revision 의 worktree 를 만드는 비용이 한 번 든다. 이후에는 캐시를 쓴다.
- 이 레포에서 표준을 고칠 때는 아무것도 달라지지 않는다. 대상이 자기 자신이면 넘기지 않는다.
