---
type: adr
id: 0017
status: accepted
date: 2026-09-09
---

# 0017. 표준은 branch 이름을 갖지 않는다

`branch-defaults` 를 제거한다. branch 이름과 접두사는 프로젝트가 선언하고, 선언하지 않으면 도구는
답하지 않는다. [ADR 0014](0014-projects-name-their-branches.md) 의 기본값 결정을 대체한다.

## 결정

- 계약에서 `branch-defaults` 를 지운다. 표준에 `develop` · `main` · `feat/` 같은 이름이 남지 않는다.
- `vcs.branch.model` 을 선언했는데 `roles` 가 없으면 `engsys vcs check-settings` 가 무엇을 선언해야
  하는지 알리고 실패한다.
- `engsys vcs base-branch` 는 `roles` 선언이 없으면 답하지 않고 그 사실을 알린다. 빈 값을 돌려주면
  hook 이 그것을 branch 이름으로 쓴다.
- `vcs.branch` 를 두지 않은 프로젝트는 branch 규약을 채택하지 않은 것으로 보고 판정하지 않는다.
  `vcs.commit` 만 선언한 프로젝트가 branch 검사 때문에 실패하지 않는다.
- hotfix 분기는 `prefixes.hotfix` 를 선언했을 때만 갈라진다. 선언하지 않으면 hotfix branch 도 첫
  역할 branch 에서 분기한다. 도구는 선언하지 않은 것을 추측하지 않는다.

## 배경과 제약

ADR 0014 는 이름을 프로젝트로 옮기면서 계약에 기본값을 남겼다. 선언하지 않은 기존 프로젝트가 채택
첫날 실패하지 않게 하려는 것이었다.

그 결과 표준이 `develop` 과 `feat/` 를 들고 있었다. 선언을 빠뜨린 프로젝트는 남의 팀 이름을
물려받고, 그 사실이 어디에도 드러나지 않았다. `public-ai-qa` 가 그 상태였다 — `roles` 를 선언하지
않아 표준의 기본값으로 동작하고 있었다.

제약이 하나 있었다. 기본값을 없애면 선언하지 않은 프로젝트에서 도구가 답할 수 없다. 그러나
`engsys init --detect` 가 실재하는 branch 에서 역할을 읽어 쓰므로 새 프로젝트는 영향을 받지 않는다.

## 근거와 대안

- **기본값을 남기고 `doctor` 가 경고한다**: 경고는 읽히지 않는다. 그리고 경고를 읽기 전까지 그
  프로젝트의 hook 과 skill 은 남의 팀 이름으로 동작한다.
- **이름 없이 역할만으로 동작한다**: `base-branch` 가 역할 이름을 돌려주면 hook 이 `git` 에 넘길 수
  없다. 어딘가에서는 실제 이름이 필요하고, 그 자리는 프로젝트다.
- **`init` 이 감지하지 못하면 물어본다**: `init` 은 비대화형으로도 돌아야 한다. 감지하지 못하면
  `vcs` 블록을 만들지 않고, 필요할 때 `check-settings` 가 무엇을 선언할지 알린다.

## 영향

- `vcs.branch.model` 을 선언한 프로젝트는 `roles` 도 선언해야 한다. `public-ai-qa` 는 이 결정에
  앞서 선언했다.
- `prefixes.hotfix` 를 선언하지 않으면 hotfix 분기 기준이 일반 작업과 같아진다. 이전에는 표준의
  기본값 때문에 갈라졌다. 갈라야 하면 선언한다.
- 표준을 읽는 사람이 `develop` 이라는 이름을 어디에서도 보지 않는다. 그 이름은 각 프로젝트의
  계약에만 있다.
