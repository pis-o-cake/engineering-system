---
type: decision-record
id: 0024
status: accepted
date: 2026-09-10
---

# 0024. The project declares its tracker and agent permissions

The standard holds when an unresolved item is registered, what it must record, and what closes it.
Which tool to write to with which labels, and how far an agent may act on its own, are declared by
the project in `vcs.tracker`. The standard holds no tracker name, no label name and no permission
value.

## Decision

- `packages/vcs-gov/tracker-contract.yaml` holds the item kinds and the nature of their closing
  conditions, the required information, the duplicate check, the four registration points, the
  extraction rules, the closing evidence, and the two axes of cost recording.
- The project declares `provider`, `project`, `default-assignee`, `labels` and `agent` in
  `vcs.tracker`. `engsys vcs tracker` answers with the resolved values, and
  `engsys vcs check-tracker` judges the declaration. Without a declaration, the tools give no
  answer.
- The only values for `agent` are `allowed` and `ask`. The contract fixes `accept-risk` and
  `commit-deadline` as `always-human`, and a project cannot open them up as `allowed`.
- If the `영향 및 후속 작업` (Impact and follow-up work) section of a merge request body contains
  an expression indicating follow-up work but no tracked item link, the gate blocks it. It checks
  only the link format, not the item's content.
- The `track-unresolved` skill provides lookup, duplicate check, registration and evidence update as
  one flow, and `write-merge-request` hands off to it before writing the last section.

## Context and constraints

[docs/design/0003](../design/0003-unresolved-item-ledger.md) decided to link unresolved items to
work items that have an assignee and a closing condition, with documents no longer managing that
state themselves. That proposal laid out an order: operate real changes manually first, then promote
only what recurs into the contract.

Operating manually first loses more than it gains. If people have to remember the skill name, call
it, and fill in a form, it is the first thing skipped when they are busy. Skipped records cannot
show whether this procedure is worth using. So the order is reversed: the procedure is connected to
the existing workflow first, and the items that workflow creates, along with the merge requests
themselves, serve as operating evidence. No separate manual ledger is created.

The constraint is the same one [ADR 0017](0017-the-standard-holds-no-branch-names.md) set for branch
names. This repository's ledger is GitHub Issues, and `public-ai-qa` uses GitLab Issues. If the
standard named one of them, a project that omitted the declaration would inherit someone else's
tool.

Permissions carry one more constraint. Asking for confirmation at every registration removes the
benefit of automation, and delegating everything removes judgements a person has to own. Risk
acceptance and deadline commitment sit on that boundary.

## Rationale and alternatives

- **Have the standard pick one tracker**: the implementation would be shorter. But teams use
  different tools, and even within one team the standard repository and the product repository use
  different places. That is the case right now.
- **Ask for permission at every registration**: safe, but it removes the reason for automation. It
  is better to decide once through the declaration and operate within it. The contract fixes to a
  person only the judgements that cannot be undone.
- **Leave the missing-link check to human review instead of a hook**: this was the approach until
  now, and bodies that listed follow-up work without saying where it was tracked did appear. What a
  machine can judge, the machine checks.
- **Have the gate judge item content too**: a machine cannot judge whether a closing condition is
  sufficient or whether the assignee is right. It checks only that the link exists.

## Consequences

- Nothing changes for a project that does not declare `vcs.tracker`. `tracker` and `check-tracker`
  output nothing, and the gate's missing-link check runs only when the body contains an expression
  the contract declares.
- A merge request that lists follow-up work but omits the link cannot be opened. If nothing remains,
  write `없음` (none).
- A project that declares `accept-risk` or `commit-deadline` as `allowed` fails `check-tracker`.
  These two cannot be opened up by declaration.
- This decision adds one responsibility to the standard. Whether to adopt it is decided in decision
  item #27, after operating one case of each of the three kinds.
