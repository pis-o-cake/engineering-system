---
type: adr
id: 0009
status: accepted
date: 2026-09-08
---

# 0009. The document structure check moves to write time and its result goes back to Claude

Right after a document is written, only that document is structure-checked, and failures are
returned to Claude inside the session. The review receipt check does not move and stays in the push
gate. A `Stop` hook that verifies everything on every turn remains unused.

## Decision

- A `PostToolUse` hook checks the single Markdown or HTML file just written with
  `engsys docs check --path`. On failure it exits 2 so that stderr is delivered to Claude, and
  Claude fixes the problem on the spot.
- `engsys docs check --path <document>` finishes without error for an unassigned path, a missing
  file, or a project with no `authoring` declaration. This keeps a hook that runs on every write
  from producing noise.
- A `SessionStart` hook injects the remaining structure findings and the number of unreviewed
  documents as one line. It blocks nothing, and prints nothing when no problems remain.
- The editorial review receipt check does not move to write time. It stays in `engsys verify` and
  the push gate.
- The `Stop` hook and the `UserPromptSubmit` classifier remain unused.

## Background and Constraints

v0.1 put every check in the push gate. So if you wrote ten documents and pushed, the problems in all
ten came out at once at that point. By then it is already unclear which edit broke what.

The context budget in [design 0001](../design/0001-foundation.md) made automatic verification on
`Stop` and the `UserPromptSubmit` classifier non-goals, because they add context and friction on
every turn. The same document also set the scope of hooks: hooks only do things that need no judgment.

## Rationale and Alternatives

- **Run `engsys verify` in a `Stop` hook**: deterministic, but native tests would run on every turn,
  taking tens of seconds while the user waits. Even when it fails, it does not say which edit was
  the cause. The reasons for keeping it a non-goal remain unchanged.
- **Write "run verify after changes" into a route rule**: no cost, but no guarantee either. It runs
  only when the model follows that sentence.
- **Check one file right after it is written**: whether a required section is present is not a
  judgment, so it falls within the scope of hooks. The cost is a single file, the cause is the file
  just written, and the result goes to Claude so the user does not have to step in. This is the
  option chosen.
- **Require review receipts at write time too**: "not reviewed" would appear at every point
  mid-writing. Review is a notion of completion, so requiring it in an intermediate state becomes
  noise. It stays in the push gate.

## Consequences

- `PostToolUse` runs after the write, so it cannot block; it makes Claude fix the problem. When a
  person edits a document directly in an editor, this layer does not catch it, and the push gate
  catches that case.
- `docs check` and `review check` each run once at every session start. If they get slow in a
  project with many documents, they are cut off at the 20-second timeout, and the session still
  starts normally when that happens.
- With three hooks, plugin manifest generation had to support events without a matcher.
  `SessionStart` has no matcher.
- This layer looks only at structure. Whether sentences and evidence are appropriate is still
  judged by the individual editorial review in [ADR 0005](0005-individual-document-editorial-review.md).
- What `SessionStart` counts was superseded by
  [ADR 0010](0010-session-start-counts-review-backlog-only.md). Measurement showed that the full
  structure check was not worth running every session. The remaining decisions stand.
