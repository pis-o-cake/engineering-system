---
name: track-unresolved
description: Search, register and update the unresolved-item tracker for work this change does not close. Use at session start, when something cannot be closed now, while writing a merge request, and when finishing work.
---

# Track an unresolved item

Work that a change does not close belongs in a tracked item with one owner and a closing
condition, not in a document and not in a TODO comment. Documents link to the item; they do not
restate its status.

Read the standard's rules and the project's declaration before touching a tracker:

```sh
"$ENGSYS_PLUGIN_ROOT/packages/vcs-gov/tracker-contract.yaml"
"$ENGSYS_PLUGIN_ROOT/bin/engsys" vcs tracker --project <project>
```

`vcs tracker` prints the provider, the tracker project, the default assignee, the label mapping
and the agent permissions. A project that declares no `vcs.tracker` prints nothing — then say so
and stop. Never guess a tracker, a label or a permission the project did not declare.

## Permissions

Every action is `allowed` or `ask` in the printed permissions. `allowed` means do it and report
it. `ask` means propose the exact action and wait. Accepting a risk and committing to a deadline
are always the human's, whatever the declaration says. Asking before every registration removes
the point of the automation; acting on a risk acceptance removes the point of the human.

## The four moments

Do not wait to be called by name. These are the points where this skill belongs.

**Starting work.** Search the tracker for open items touching this change — the files, the
component, the linked merge requests. Summarise what is already known so the work does not restart
from zero. This is a search; it needs no permission beyond the declared one.

**Finding something that cannot be closed now.** Search before you register. Match on title
keywords, referenced file paths, and linked merge requests. If an existing item covers it, add the
new evidence there instead of opening a second one. Only when nothing matches, register.

**Making the change.** Link the item and the merge request both ways. Record which documents this
change affects and what remains unverified in the merge request's `영향 및 후속 작업` section.

**Finishing.** Compare the closing conditions against the evidence you actually have. Update the
item or write down what is still missing. Creating a follow-up item is not a completion verdict —
if the missing work is a required condition of this change, the change is not done.

## Filling an item

Extract the fields from the current conversation, the working tree diff and the verification
output. Do not hand the human a form.

Required: kind, title, impact, evidence, and at least one closing condition. One assignee, not
several. Write a closing condition as what to check, not as what to improve — "조기 EOF 뒤 오류
안내와 재입력이 가능하다" rather than "SSE 처리를 개선한다".

Leave what you do not know as `미정`. Never invent an assignee, a deadline or a decision. Ask only
for values the contract requires and you cannot extract.

Pick the kind from the contract's list, because the closing condition follows from it:

| Kind | Closes with |
|---|---|
| 결함 | 수정 후 실패 시나리오를 다시 재현해 통과 |
| 해야 할 후속 작업 | 약속한 산출물이나 실행 결과를 확인 |
| 미확정 결정 | 결정권자가 선택하고 근거를 남김 |
| 외부 답변 대기 | 답변을 받아 기준 문서에 반영 |
| 당장 해결하지 않을 위험 | 수용권자와 조건과 재검토 시점을 명시 |

Collapsing these into one TODO loses the difference between "someone must change code" and
"someone must get an answer from outside".

## Closing

Closing needs evidence: the command you ran and its result, or the merge request that carries it.
Document editing complete and behaviour verified are separate verdicts; report them separately.

## Cost

When you record cost, keep the two axes apart. Command duration, failures and retries are
measured. Review and decision time is the human's and only the human can report it. Session
elapsed time is not human working time.
