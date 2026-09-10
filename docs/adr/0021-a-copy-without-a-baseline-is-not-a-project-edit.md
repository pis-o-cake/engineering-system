---
type: decision-record
id: 0021
status: accepted
date: 2026-09-10
---

# 0021. 기준 기록이 없는 사본을 프로젝트의 수정으로 단정하지 않는다

hook 사본이 template 과 다르고 `.engsys/hooks.txt` 에 그 hook 의 기준 기록이 없으면 상태를
`unrecorded` 로 보고한다. 갱신을 막는 동작은 `modified` 와 같고, 문장만 "engsys 는 어느 쪽이
바뀌었는지 모른다"로 바꾼다.

## 결정

- 상태에 `unrecorded` 를 더한다. 조건은 하나다 — 사본이 현재 template 과 다르고 그 hook 의
  기준 기록이 없다.
- `hooks update` 는 이 상태를 그대로 두고, `--adopt` 와 `--force` 중 무엇이 어떤 경우에
  맞는지 함께 출력한다. `--force` 는 종전대로 template 으로 덮는다.
- `doctor` 는 이 상태를 `differs from the template with no baseline` 로 구분해 보고한다.
- 기준 기록이 있는 사본의 판정은 [ADR 0015](0015-hook-copies-are-diagnosed-not-overwritten.md)
  그대로다. `current` · `owned` · `outdated` · `modified` · `missing` 은 바뀌지 않는다.

## 배경과 제약

ADR 0015 는 기록이 없는 사본을 `modified` 로 묶었다. 갱신을 막는다는 점에서는 안전한
선택이었고, 그 문서의 「영향」 절도 이미 채택한 프로젝트가 처음에 `modified` 로 보인다고
적었다.

2026-09-10 Windows 재검증에서 그 선택의 비용이 드러났다. `public-ai-qa` 의 `commit-msg` 는
직전 검증까지 `current` 로 보고되던 사본이다. template 이 b955c49 에서 바뀌자
`engsys hooks status` 가 `modified` 로 돌아섰고 "프로젝트가 고친 사본이다. 갱신하면 그 수정이
사라진다"라고 답했다. 그 사본에 프로젝트가 고친 내용은 없었고, 바뀐 것은 template 뿐이다.
기록이 있었다면 `outdated` 가 나왔을 자리다.

같은 출력을 이 저장소에서 재현했다. `init --hooks` 로 심은 사본에서 `.engsys/hooks.txt`
행만 지우고 template 과 다르게 만들면 `modified` 와 "프로젝트가 고친 사본이다"가 나온다.
engsys 는 사본을 고친 적이 없다는 것을 알 수 없었을 뿐인데, 출력은 안다고 말한다.

제약은 소유권이다. 기록이 없다고 해서 덮어도 되는 것은 아니다. 프로젝트가 고친 사본일
가능성이 남아 있으므로 기본 동작은 계속 "건드리지 않는다"여야 한다. 바꿀 수 있는 것은
engsys 가 아는 것보다 더 말하지 않는 것뿐이다.

## 근거와 대안

- **`outdated` 로 묶는다**: 기록이 없는 사본을 자동 갱신 대상으로 만든다. 프로젝트가 고친
  hook 을 조용히 되돌리게 되므로 ADR 0015 가 막으려던 사고가 그대로 돌아온다.
- **문장만 고치고 상태는 그대로 둔다**: `hooks status` 출력은 나아지지만 `doctor` 와 `setup`
  이 같은 `modified` 문자열을 보고 판단하므로 분기점이 없다. 상태 이름이 필요하다.
- **기록이 없으면 사본 해시를 그 자리에서 기록한다**: 진단이 조용해지는 대신 프로젝트가 고친
  사본을 "확인함"으로 승격시킨다. 사람이 보지 않은 것을 확인했다고 적는 셈이다.

## 영향

- ADR 0015 가 정한 다섯 상태가 여섯이 된다. 그 문서의 결정 중 기록 없는 사본의 판정만
  이 문서가 대신한다.
- 이미 채택한 프로젝트가 처음 보는 문장이 바뀐다. 조치는 종전과 같다 — `--adopt` 로 현재
  사본을 기준으로 잡거나 `--force` 로 template 을 받는다.
- `public-ai-qa` 의 `commit-msg` 사본은 여전히 옛 fail-open 로직을 갖고 있다. 이 결정은
  그 사실을 정확히 보고하게 할 뿐, 반영 여부는 그 프로젝트가 정한다.
