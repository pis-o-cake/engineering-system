---
type: design-proposal
status: draft
scope: unresolved-item-linking
---

# Proposal for linking unresolved items

Anything a change could not close is linked to a work item that has an owner and a closing
condition, and the documentation does not track that state a second time. The standard owns the
linking rules and the form of the closing condition; the project owns the choice of tracker and the
progress of each item.

This document is an adoption proposal. The linking rules and the permission declaration were
implemented in
[ADR 0024](../adr/0024-the-project-declares-its-tracker-and-agent-permissions.md). Whether to keep
them is decided after running one case of each of three different kinds.

## Proposal summary

Document governance currently has two verdicts. Do the declared form and the mechanical facts hold
(structure and generated-document checks)? And was this body reviewed against its readers and
purpose (individual editorial review)? A review receipt confirms that the reviewed body is the same
as the current body, and
[ADR 0005](../adr/0005-individual-document-editorial-review.md) limits that guarantee precisely.

A third verdict is missing: **do the explanation and procedure still hold after later changes?** If
the body is unchanged, the hash is the same and the review receipt stays valid, but when the code,
configuration or decision it rests on changes, the document no longer matches.

This repository produced two such cases on a single day, 2026-09-10.

- [ADR 0015](../adr/0015-hook-copies-are-diagnosed-not-overwritten.md) stated that there were five
  hook states. After a change added a sixth state, the body and its review receipt stayed as they
  were.
- [ADR 0007](../adr/0007-one-command-activation-and-main-as-release-channel.md) rejected plugin
  marketplace distribution in its rationale and alternatives. The same happened after a change
  reversed that judgment.

Both were found because a person pointed them out, and the checks passed throughout. Both were
handled with new decision records, but the detection itself was not done by a machine.

The third verdict is not merged into individual editorial review. A review receipt today means only
"this body was read and reviewed"; adding "this was also confirmed in operation" would blur a
guarantee that is precisely limited.

## Design

### What the standard owns and what the project owns

| Responsibility | Where it lives |
|---|---|
| The question a document answers, its source of truth, its update conditions | The standard's document governance |
| Where an unresolved item is linked and what serves as its closing condition | The standard's linking rules |
| Owner, due date, progress, closing verdict | The project's work tracker |
| What changed, verification results, links to follow-up items | The existing merge request |
| Facts found and measured at the time | Review reports and experiment records |
| Risk acceptance decisions | The decision-maker's confirmation record |

The standard does not own any particular tracker. The project declares its ledger, and the standard
checks only that a link exists and that a closing condition is written. This repository's ledger is
GitHub Issues; the ledger of `public-ai-qa` is GitLab Issues. The standard does not name either one
for the same reason
[ADR 0017](../adr/0017-the-standard-holds-no-branch-names.md) gives for branch names.

### Kinds of unresolved items

Lumping all unresolved items together erases the difference between "who has to fix the code" and
"who has to fetch an answer". Each kind has a different kind of closing condition.

| Kind | Where it is tracked | Nature of the closing condition |
|---|---|---|
| Defect | Defect item | After the fix, the failure scenario is reproduced again and passes |
| Required follow-up work | Work item | The promised deliverable or execution result is confirmed |
| Open decision | Decision item, plus a decision record in proposed status if needed | The decision-maker chooses and records the rationale |
| Waiting on an external answer | Item in blocked state | The answer is received and reflected in the reference document |
| Risk not being addressed now | Item linked to a risk acceptance record | The accepting party, conditions and review date are stated |

### Form of a work item

The standard requires one owner and a closing condition that a person, not a machine, can judge.
All other fields follow the project's tool.

```
제목: 답변 종료 이벤트 없이 SSE 가 닫히면 입력이 잠기는 문제
유형: 결함
담당자: 한 명
영향 / 우선순위: 사용자 대화 지속 불가 / 다음 배포 전
근거: 검토 보고서의 해당 절 링크

종료 조건:
- 조기 EOF 뒤 오류 안내와 재입력이 가능하다.
- 해당 경로의 회귀 검사가 통과한다.

관련 변경: merge request 링크
종료 증거: 검사 결과
```

The example stays in Korean, as a Korean-language project would write it. In English it reads:

```
Title: Input locks when SSE closes without an answer-end event
Type: Defect
Owner: one person
Impact / priority: user cannot continue the conversation / before next release
Basis: link to the relevant section of the review report

Closing conditions:
- After an early EOF, an error message is shown and the user can type again.
- The regression check for that path passes.

Related change: merge request link
Closing evidence: check results
```

Do not list multiple owners. Write the closing condition as what has to be confirmed for the item
to close, not as "improve X".

### Order of handling one change

1. **Check impact** — identify which explanation in which document this change may alter.
2. **Decide handling** — update it, or briefly record that it was checked and needs no update.
3. **Review and check** — if a document was edited, run individual editorial review and the
   declared native checks.
4. **Link unresolved items** — link whatever this change could not close to a work item with a
   closing condition.
5. **Judge completion** — distinguish finishing the document edit from confirming the actual
   behavior.

The result goes in the merge request's `영향 및 후속 작업` ("Impact and follow-up work") section,
not in a separate report. That section is already part of the contract.

> 백업 volume 변경에 맞춰 복구 절차를 갱신했다. 문서 검사와 개별 검토는 완료했다. 복구 실험은
> 미실행이며 후속 항목 OPS-12 에서 추적한다.

(In English: "Updated the recovery procedure for the backup volume change. Document checks and
individual review are done. The recovery experiment has not been run and is tracked in follow-up
item OPS-12.")

**Creating a follow-up item does not by itself count as completion.** If that experiment is a
required completion condition of this change, it cannot be deferred. What can be deferred is
decided by the project's risk and release conditions.

### Scope of periodic checks

Checking at change time is the main path; periodic checks are a secondary path for catching what
was missed. Four targets are enough.

- Changes whose documentation impact was left unresolved
- Major current documents whose underlying code or configuration has changed
- Items marked done that lack the required evidence
- Documents that describe the same current fact differently

Do not make people reread every document only because its review date is old. Retained documents
are expected to be old, and for current documents whose related implementation has not changed, a
calendar-based re-review has little value. Conversely, documents that are sensitive to the
execution environment, such as recovery procedures, may need periodic experiments. The standard
does not set that interval globally; the project declares it.

### What was implemented first

The original plan to start with manual operation was reversed. If people have to remember a skill
name, invoke it and fill in a form, that is the first thing skipped when they are busy, and skipped
records cannot tell whether this procedure is useful. So it was wired into the existing workflow
first, and the items that workflow creates, together with the merge requests themselves, serve as
operating evidence. No separate manual ledger is kept.

- `packages/vcs-gov/tracker-contract.yaml` — item kinds and closing conditions, required
  information, duplicate checks, registration timing, extraction rules, closing evidence, and the
  two axes of cost recording
- The `vcs.tracker` declaration and `engsys vcs tracker` · `check-tracker`
- The `track-unresolved` skill — lookup, duplicate check, registration and evidence update in one
  flow
- The merge request gate's missing-link check — it blocks a merge request that lists follow-up
  work without a link

`packages/docs-gov/policy.yaml` and the documentation-side contract were not extended. Whether to
raise the third verdict into the document governance contract is judged separately in a decision
item.

Operating cost is recorded against the criteria in the
[adoption evaluation specification](../verification/adoption.md). That document already covers
search, editing, review, false-positive recovery and maintenance time, and it states that a rule
with no additional detections and steadily growing review and maintenance time has its scope
reduced or is removed. This proposal adds **inconsistencies found while the body was unchanged** as
an item there.

### First operating targets

Three cases of different kinds are included. Only that shows whether the procedure merely handles
wording fixes well or also supports real operating judgments.

- Checking current documents after a change in code behavior
- Changes to release and recovery procedures, linked to execution evidence
- Tracking an open decision until its criteria are settled

The judgment is by kind, not by count. Repeating the same kind ten times does not show whether the
procedure only handles wording fixes well. The release/recovery case and the open-decision case
target `public-ai-qa`, and a passing native check in that project is a precondition.
