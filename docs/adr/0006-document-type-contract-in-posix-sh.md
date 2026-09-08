---
type: adr
id: 0006
status: accepted
date: 2026-09-08
---

# 0006. 문서 유형 계약은 docs-gov가 소유하고 구조 검사는 POSIX sh로 둔다

유형별 독자·필수 metadata·필수 절의 정본을 `packages/docs-gov/document-types.yaml` 하나로 두고,
프로젝트는 경로에 유형을 배정하는 선언만 갖는다. 구조 검사 `engsys docs check`는 dependency 없는
POSIX sh로 구현한다.

## 결정

- 유형 계약의 정본은 `packages/docs-gov/document-types.yaml`이다. 유형마다 독자, 문서가 답할 질문,
  필수 frontmatter, status 어휘, `frozen-status`, 필수 절을 선언한다.
- 프로젝트는 `.engsys/project.yaml`의 `documentation.authoring`에서 경로에 유형을 배정하고
  (`assign`), 검사 대상이 아닌 경로(`exempt`)와 절 검사를 유예할 경로(`deferred`)를 선언한다.
  공통 유형 규칙을 프로젝트에 복사하지 않는다.
- 필수 절은 heading 문자열을 고정하지 않고 정규식 `pattern`으로 확인한다. `frozen-status`에
  해당하는 기록은 절의 존재만 보고 순서는 보지 않는다.
- 구조 검사는 `packages/docs-gov/bin/check-structure.sh`이며 `engsys docs check`로 실행한다.
  Markdown은 frontmatter, HTML은 `<meta name="doc-*">`로 같은 metadata를 선언한다.
- 검사 범위는 구조와 근거 경로의 존재까지다. 문장의 적절성과 근거의 충분성은
  [ADR 0005](0005-individual-document-editorial-review.md)의 편집 검토가 판단한다.

## 배경

[design 0002](../design/0002-document-authoring-contracts.md)는 유형별 필수 구성과 그 구조 검사를
요구했지만, `docs-gov`에는 lifecycle 분류와 편집 검토만 있었다. 유형 선택은 작성자의 기억에
맡겨져 있었고, 필수 절 누락을 막는 검사가 없었다.

구현 과정에서 두 개의 안이 동시에 만들어졌다. 하나는 python으로 쓴 검사기, 다른 하나는 sh로 쓴
검사기였고, 계약 모델과 구현 언어를 각각 선택해야 했다.

## 근거와 대안

- **python으로 구현한다**: 정규식·경로 처리와 YAML 읽기가 짧아진다. 그러나 프로젝트가 매번
  실행하는 검사가 python3를 요구하게 되어 [ADR 0001](0001-posix-sh-core-with-python-tooling.md)이
  나눈 실행 주체의 경계가 깨진다. 이 표준은 Windows 개발 서버와 Android 프로젝트에도 적용할
  계획이므로 채택 전제를 늘리지 않는다.
- **필수 절을 heading 문자열로 고정한다**: 검사와 안내가 단순해지지만 계약보다 먼저 쓰인 문서를
  전부 유예 목록에 넣어야 한다. 유예가 기본값이 되면 검사가 형식만 남는다.
- **유형마다 별도 skill을 만든다**: 작성 안내는 친절해지지만 안내문과 검사기가 서로 다른 필수
  구성을 갖게 된다. 하나의 선언을 skill과 검사기가 함께 읽는 쪽을 택했다.

## 영향

- 유형이나 필수 절을 바꾸면 이 레포의 `engsys docs check`가 먼저 깨진다. 채택 비용을 먼저
  치른다는 [ADR 0004](0004-self-hosted-first-pilot.md)의 방식을 유지한다.
- sh 파서는 `document-types.yaml`의 선언 깊이에 의존한다. 선언이 지금보다 깊어지면 ADR 0001의
  경계를 다시 검토한다.
- 이 레포의 `docs/design` 두 편은 계약보다 먼저 작성됐으므로 `deferred`로 두어 절 검사를
  유예했다. metadata와 근거 경로는 계속 검사한다. 전환은 그 문서를 실제로 편집할 때 한다.
- 구조 검사 통과는 검토가 아니다. 새 문서는 `engsys docs check`와 개별 편집 검토를 모두 거쳐야
  완료된다.
