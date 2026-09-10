---
type: adr
id: 0007
status: accepted
date: 2026-09-08
superseded-in-part-by: 0023
---

# 0007. 활성화는 install script 하나로 두고 배포 채널은 origin/main으로 한다

팀원의 활성화를 `./install.sh` 한 번으로 줄이고, 빠진 것은 `engsys doctor`가 실행할 명령과 함께
보고한다. 표준의 배포 채널은 `origin/main`이며, lock은 명령을 실행한 checkout의 revision을 기록한다.

## 결정

- 개발자 활성화는 `install.sh` 하나다. 개발자 자신의 shell profile 한 줄과 이 clone의
  `core.hooksPath`만 바꾸고, 표준을 채택하는 프로젝트에는 아무것도 쓰지 않는다. 두 번 실행해도
  결과가 같으며, profile이 다른 checkout을 가리키면 덮지 않고 그 줄을 보고한다.
- 진단은 `engsys doctor`다. system checkout revision, PATH 연결, push gate 등록, 계약과 lock의
  `engsys check` 통과, locked revision의 가용성, `origin/main`과의 차이를 보고한다. 고칠 수 있는
  문제가 있으면 exit 1이고, 각 항목에 실행할 명령을 함께 출력한다.
- 배포 채널은 `origin/main`이다. 특정 release에 고정하려면 그 tag를 checkout한 뒤 `upgrade`를
  실행한다. lock은 언제나 명령을 실행한 checkout의 revision을 기록한다.
- `doctor`는 lock이 `origin/main`에서 도달 불가능해도 실패로 세지 않고 경고한다. 표준을 고치는
  동안 자기 branch revision에 lock하는 흐름을 막지 않기 위해서다.

## 배경과 제약

v0.1의 활성화는 세 단계였다. clone, shell profile에 `eval "$(... shellenv)"` 추가,
`git config core.hooksPath .githooks`. 팀원마다 반복해야 하고, 빠뜨려도 알려 주는 것이 없었다.
hook 등록 누락은 특히 조용하다. CI runner가 없어 `.githooks/pre-push`가 이 레포의 유일한
gate이므로([ADR 0002](0002-contract-schema-is-canonical.md)의 근사 검사와 별개로), 등록하지 않은
개발자는 아무 검사 없이 push한다.

`system.yaml`은 release delivery를 `private-marketplace`로 선언했지만 구현이 없었다. 팀원이 실제로
표준을 얻는 경로는 "내 로컬 clone 경로를 알려 준다"였다.

제약은 [ADR 0001](0001-posix-sh-core-with-python-tooling.md)과 같다. 채택 비용을 늘리지 않기 위해
`install.sh`도 dependency 없는 POSIX sh다.

## 근거와 대안

- **Claude Code plugin marketplace로 배포한다**: 활성화가 더 짧아진다. 그러나 marketplace는 plugin
  버전을 개발자 단위로 고정하고, 이 시스템은 프로젝트 단위로 고정한다
  ([ADR 0003](0003-skill-uses-launcher-environment.md)의 launcher가 lock revision으로 plugin view를
  조합하는 구조). 두 고정 축이 충돌하므로 v0.1에서는 쓰지 않는다.
- **문서로만 안내한다**: 지금까지의 방식이다. 누락을 검사하는 것이 없어 hook 미등록을 발견할
  방법이 없다.
- **`doctor`가 발견한 문제를 자동으로 고친다**: 짧아 보이지만 shell profile을 조용히 바꾸게 된다.
  진단과 수정을 나눠, 수정은 개발자가 `install.sh`를 실행할 때만 일어나게 했다.
- **`upgrade --to <tag>`를 만든다**: 검토했고 이번에 넣지 않았다. 대상 revision의 package version과
  profile을 그 revision에서 읽어야 하는데 현재 구현은 working tree에서 읽는다. checkout 후
  `upgrade`로 같은 결과를 얻을 수 있어, 잘못 읽을 위험을 지금 만들지 않는다.

## 영향

- 팀원의 활성화는 clone과 `install.sh` 두 단계다. 빠진 것은 `engsys doctor`가 보고한다.
- `install.sh`는 개발자의 shell profile에 두 줄을 추가한다. 되돌리려면 그 줄을 지운다.
- lock을 push하지 않은 revision에 두면 팀원의 clone이 그 revision을 fetch하지 못한다. `doctor`가
  경고하지만 막지는 않는다.
- `upgrade`는 여전히 실행한 개발자의 checkout revision을 기록한다. 팀이 같은 revision을 쓰려면
  checkout을 먼저 맞춰야 한다. 이 수동 단계가 실제로 문제를 만들면 `--to`를 다시 검토한다.
