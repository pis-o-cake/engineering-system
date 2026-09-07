# Engineering System

프로젝트마다 같은 개발 판단을 반복 가능하게 만드는 실행형 표준이다.

## 경계

- 이 레포는 package, profile, Claude Code plugin, schema, fixture의 정본이다.
- 프로젝트는 `.engsys/project.yaml`과 `.engsys/lock.yaml`으로 선택한 표준과 버전을 선언한다.
- 공통 정책·skill·hook을 프로젝트에 복사하지 않는다.
- 확정적인 규칙은 프로젝트 native test·Git hook·CI가 검사한다.

## v0.1

첫 package는 `foundation`과 `documentation-governance`다. `public-ai-qa`는 첫 pilot이며
공통 표준의 정본은 아니다.

- [Foundation design](docs/design/0001-foundation.md)
- [System catalog](system.yaml)
- [Project contract schema](schemas/project.schema.json)
- [Project lock schema](schemas/lock.schema.json)
- [Baseline profile](profiles/baseline.yaml)
- [Bootstrap workflow](workflows/bootstrap.yaml)

## Local use

개발 중에는 한 번만 plugin directory를 연결한다.

```sh
claude --plugin-dir /path/to/engineering-system
```

대상 Git 프로젝트에서는 dependency 설치 없이 adapter만 만든다. `init`은 기존 계약을 절대
덮어쓰지 않으며, manifest를 수동으로 바꾼 뒤에는 `sync`와 `check`를 차례로 실행한다.

```sh
/path/to/engineering-system/bin/engsys init --verify 'make check'
/path/to/engineering-system/bin/engsys check
```
