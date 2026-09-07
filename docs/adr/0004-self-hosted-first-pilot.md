---
type: adr
id: 0004
status: accepted
date: 2026-09-07
---

# 0004. 이 레포를 표준의 첫 pilot으로 삼는다

## 맥락

v0.1 설계는 첫 pilot을 별도 프로젝트(`public-ai-qa`)로 잡았다. 그동안 이 레포 자신은
`.engsys/` 계약도, ADR도, 생성 문서도 없었다. ADR과 생성 문서를 배포하는 레포가 그 둘 중
어느 것도 쓰지 않는 상태였다.

표준을 채택하는 비용을 가장 먼저, 가장 싸게 측정할 수 있는 프로젝트는 이 레포다. 여기서
불편한 것은 다른 프로젝트에서도 불편하다.

## 결정

- 이 레포에 `engsys init`으로 계약을 만들고 `.engsys/`를 커밋한다.
- 문서를 세 가지 책임으로 나눠 실제로 운영한다.
  - `docs/design/` — 그때의 판단 (frozen status: `implemented`)
  - `docs/adr/` — 그 뒤의 변경 이유 (frozen status: `accepted`)
  - `docs/architecture/` — 지금 상태
- package·skill·hook 목록처럼 선언에서 결정적으로 얻을 수 있는 사실은
  `docs/generated/system-catalog.md`로 생성하고, 직접 수정은 hook이 막고 최신 여부는
  `engsys verify`가 검사한다.
- `commands.verify`는 `sh tests/test-all.sh`이며, 그 안에서 이 레포 자신의 계약 검사도 돈다.

## 대안

- **외부 pilot만 사용한다**: 실제 제품에서 검증한다는 장점은 있지만 표준을 고칠 때마다
  다른 레포를 오가야 하고, 표준이 자기 규칙을 어겨도 아무도 모른다.
- **dogfooding을 문서로만 선언한다**: 강제 지점이 없으므로 바빠지는 순간 제일 먼저 빠진다.

## 결과

- 표준을 바꾸면 이 레포의 계약과 생성 문서가 먼저 깨진다. 채택 비용을 매번 직접 치른다.
- `public-ai-qa`는 두 번째 pilot으로 남는다. 언어·framework가 있는 실제 프로젝트에서만
  드러나는 문제는 거기서 확인한다.
