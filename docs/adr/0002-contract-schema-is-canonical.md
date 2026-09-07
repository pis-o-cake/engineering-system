---
type: adr
id: 0002
status: accepted
date: 2026-09-07
---

# 0002. 계약 형식의 정본은 JSON Schema로 두고 sh check는 근사로 둔다

## 맥락

`schemas/project.schema.json`과 `schemas/lock.schema.json`은 v0.1 초기부터 있었지만 어떤
코드도 이 파일을 읽지 않았다. 실제 검사는 `engsys check`의 `grep` 검사였고, 계약을 쓰는 쪽은
`write_project_contract`의 `printf`였다. 형식의 정본이 schema·writer·parser 세 곳으로 갈라져
있었고, 셋 중 어느 하나가 바뀌어도 나머지가 알 수 없었다.

이것은 이 시스템이 문서에 대해 지적하는 문제와 같은 구조다. 사람이 같은 사실을 여러 곳에
관리하면 결국 갈라진다.

## 결정

- 계약 형식의 **정본은 JSON Schema**다.
- 프로젝트에서 도는 `engsys check`는 dependency 없이 실행돼야 하므로 schema를 직접 읽지 않고,
  필수 항목과 최상위 key 집합만 검사하는 **근사**로 남는다.
- 근사와 정본이 갈라지지 않는다는 것은 시스템 레포의 test가 보장한다.
  `tests/test-schema.sh`는 bootstrap이 만든 계약을 schema로 검증하고, 같은 위반을
  `engsys check`도 거부하는지 확인한다.
- schema에 새 keyword를 추가하려면 `tools/lib/jsonschema_min.py`에 구현을 추가해야 한다.
  미구현 keyword를 만나면 검증기는 통과시키지 않고 즉시 실패한다.

## 대안

- **schema를 삭제한다**: 이중 관리는 사라지지만 계약 형식을 기계가 읽을 수 있는 정본이
  없어진다. 편집기 지원과 외부 도구 연동도 포기하게 된다.
- **`engsys check`가 schema를 직접 검증한다**: 정본이 하나가 되지만 프로젝트에 JSON Schema
  검증기를 요구한다. [ADR 0001](0001-posix-sh-core-with-python-tooling.md)의 경계를 깬다.
- **검증기가 미구현 keyword를 건너뛴다**: 구현이 쉬워지지만 schema가 다시 장식이 된다.
  검사를 통과했다는 신호가 거짓이 되는 쪽이 더 나쁘다.

## 결과

- 계약 형식을 바꾸려면 schema를 먼저 고쳐야 하고, writer나 sh check가 따라오지 않으면
  `sh tests/test-all.sh`가 실패한다.
- 프로젝트가 계약을 손으로 고쳤을 때 sh 근사가 놓치는 위반은 여전히 존재한다. 그 범위는
  최상위 key와 필수 항목 밖의 세부 형식이다.
