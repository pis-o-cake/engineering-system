# Engineering System

`.engsys/project.yaml`은 이 프로젝트의 표준 계약이다.

- 구조적 변경 전에는 `/engsys:classify-change` skill을 사용한다.
- 생성 문서와 frozen historical record는 선언된 lifecycle을 따른다.
- project manifest의 native verify command를 정본으로 사용한다.
- 문서를 새로 쓰거나 구조를 바꾸기 전에 `/engsys:write-document` 로 유형과 규칙을 정한다.
- 문서 작성·수정은 `/engsys:review-document`로 한 편씩 편집 검토한 뒤 완료한다.
