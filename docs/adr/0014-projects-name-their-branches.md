---
type: adr
id: 0014
status: accepted
date: 2026-09-09
---

# 0014. branch 이름은 프로젝트가 정하고 model 은 역할만 정의한다

`vcs-gov` 의 branch model 은 역할과 분기·승격 방향만 정의한다. 실제 branch 이름과 접두사는
프로젝트가 `vcs.branch` 에 선언하고, hook 과 검사기와 skill 은 그 선언을 읽는다. 어느 도구도
`develop` 이나 `main` 을 하드코딩하지 않는다.

## 결정

- model 은 `required-roles` 와 `extra-roles` 로 역할 구성을 정의한다. `env-branch` 는
  `development` 와 `production` 을 요구하고 그 사이에 환경을 더 둘 수 있다. `single-main` 은
  `production` 하나만 쓴다.
- 프로젝트는 `vcs.branch.roles` 에 역할과 branch 이름을 선언한다. **선언 순서가 승격 순서다.**
  `vcs.branch.prefixes` 는 `feature` · `fix` · `hotfix` 의 접두사를 정한다.
- 선언하지 않으면 계약의 `branch-defaults` 를 쓰되 model 이 요구하는 역할만 남긴다. 기존
  프로젝트는 `develop` · `main` · `feat/` · `fix/` · `hotfix/` 로 이전과 같이 동작한다.
- `engsys vcs base-branch` 가 분기 기준을 답한다. hotfix 접두사로 시작하는 branch 는 마지막 역할
  branch 에서, 나머지는 첫 역할 branch 에서 분기한다.
- `engsys vcs check-settings` 가 선언을 검사하고 `engsys verify` 가 이를 부른다. 알 수 없는 model,
  필수 역할 누락, model 이 쓰지 않는 역할, 중복 branch, `protected` 에 빠진 역할 branch, 역할
  branch 가 아닌 MR 대상, `/` 로 끝나지 않는 접두사를 각각 구체적으로 알린다.
- 이름 검사는 `vcs.branch.naming` 을 선언했을 때만 한다. 접두사 선언은 도구가 읽을 값이지 강제
  대상이 아니다.
- `engsys init --detect` 는 실재하는 branch 에서 역할을 읽는다. 없는 branch 를 지어내지 않는다.

## 배경과 제약

프로젝트는 model 과 `protected` 목록만 선언할 수 있었다. 실제 이름은 각 도구에 흩어져 있었고,
`public-ai-qa` 의 `pre-push` 는 `origin/develop` 과 `origin/main` 을 직접 적었다. 이름을 바꾸려면
표준과 프로젝트 문서와 hook 을 각각 고쳐야 했다.

`branch-models` 의 `naming` 도 고정 문자열이라 다른 접두사를 쓰는 팀이 model 을 고를 수 없었다.

제약이 하나 있다. 이 선언은 로컬 규칙이다. Git 서버의 protected branch 설정은 이 선언으로 적용되지
않으며, 서버에서 막으려면 그쪽 설정을 따로 해야 한다.

## 근거와 대안

- **역할을 mapping 으로 선언한다**: `development: develop` 이 읽기 쉽다. 그러나 승격 순서를 표현할
  수 없다. 환경이 셋 이상이면 순서가 곧 정책이므로 목록으로 선언한다.
- **접두사 선언을 이름 강제와 묶는다**: 접두사를 선언하면 그 접두사만 허용하는 안이다. 실제
  저장소에는 `docs/` · `refactor/` 같은 branch 가 함께 있어 채택 첫날 정상 작업이 막힌다. 강제는
  `naming` 을 선언했을 때만 한다.
- **기본값 없이 선언을 요구한다**: 모든 기존 프로젝트가 처음부터 실패한다. 기본값을 두되 model 이
  요구하는 역할만 남겨 `single-main` 프로젝트가 쓰지 않는 역할 때문에 실패하지 않게 한다.
- **hook 이 설정을 직접 파싱한다**: 프로젝트마다 같은 파서를 다시 쓴다. `base-branch` 한 명령으로
  답을 주고 hook 은 그것을 부른다.

## 영향

- 이름을 바꾸면 `roles` 와 `prefixes` 한 곳만 고친다. `base-branch` 를 쓰는 hook 과 skill 이 함께
  따라간다.
- 기존 프로젝트가 소유한 hook 은 자동으로 바뀌지 않는다. 하드코딩된 이름을 `engsys vcs base-branch`
  호출로 바꾸는 것은 그 프로젝트의 작업이다.
- `vcs` 를 선언한 프로젝트는 `engsys verify` 에서 설정 검사를 함께 받는다. 잘못된 선언은 push 전에
  걸린다.
- 서버의 protected branch 설정은 여전히 사람이 한다. 이 선언은 그것을 대신하지 않는다.
- 선언하지 않았을 때 계약 기본값을 쓰던 결정은
  [ADR 0017](0017-the-standard-holds-no-branch-names.md)이 대체했다. 표준이 이름을 들고 있으면
  선언을 빠뜨린 프로젝트가 남의 팀 이름을 물려받는다. 나머지 결정은 그대로다.
