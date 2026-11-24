---
type: adr
id: 0010
status: accepted
date: 2026-09-09
---

# 0010. SessionStart counts only the review backlog and does not recheck structure

The full structure check is removed from the session start hook. It counts only documents without a
review receipt and does not call the launcher. The measured time drops from 7.2 seconds to 0.16 seconds.
This supersedes the SessionStart decision in [ADR 0009](0009-document-structure-feedback-at-write-time.md).

## Decision

- The `SessionStart` hook counts only **documents without a review receipt file** within the
  contract's `documentation.review.scopes`. It does not count structure findings.
- The hook does not run `engsys`. It reads only the contract and file existence, so it works
  without `CLAUDE_PLUGIN_ROOT`.
- All declared scopes are passed to `git ls-files` at once. Spawning git per scope would slow down
  in proportion to the number of declarations.
- The hook timeout is lowered from 20 seconds to 5 seconds.

## Background and Constraints

ADR 0009 had `SessionStart` run `docs check` and `review check` once each. That document's
consequences section left "if they get slow in a project with many documents, they are cut off at
the timeout" unconfirmed.

Measured on `public-ai-qa` (77 assigned documents, 77 in `review.scopes`):

| Item | Measured |
|---|---|
| `docs check`, all documents | 5.1 s |
| `review check`, all documents | 2.2 s |
| `SessionStart` total | **7.2 s, no output** |

That repository had 0 findings and 0 pending, so the hook was correctly silent. In other words, in
a clean repository it spends 7.2 seconds every session and says nothing. It did not hit the
timeout, so the remaining issue is value for cost.

Most of the cost is `docs check`, which spawns awk several times per document.

## Rationale and Alternatives

- **Remove the structure check from SessionStart**: `PostToolUse` checks structure precisely for
  just that document at write time (0.145 s), and the push gate covers the rest. The value unique
  to `SessionStart` is the review backlog that this session did not create. Only that is kept.
- **Approximate structure cheaply**: this option would skim only frontmatter and count missing
  `type`. The type contract would then be interpreted in two places, producing a state in which the
  guidance and the check have different required compositions.
  [design 0002](../design/0002-document-authoring-contracts.md) forbids that state.
- **Also compare review receipts against the body hash**: accurate, but every document would be
  rehashed every session. Checking only file existence takes 0.16 seconds, and the one thing it
  misses is "documents whose body changed after review". That usually happens during a session, and
  `engsys review check` and the push gate catch it.
- **Remove SessionStart**: the layer that reports the backlog disappears. At 0.16 seconds it is
  worth keeping.
- **Optimize `docs check` itself**: fixing the structure that spawns awk per document would make
  this hook cheaper too. That change means rewriting the whole checker, so it was not done this
  time. In the push gate and `verify`, 5.1 seconds is buried under the backend checks, so it is not
  urgent now.

## Consequences

- On `public-ai-qa`, the time went from 7.2 seconds to 0.16 seconds. Both values were measured on
  the same repository with the same declarations.
- `SessionStart` speaks only in projects that declare `documentation.review.scopes`. Without the
  declaration it prints nothing.
- This hook does not count documents whose body changed after review. That state is caught by
  `engsys verify` and the push gate.
- The other decisions of ADR 0009 (the write-time structure check in `PostToolUse`, not moving the
  review receipt check, and not using a `Stop` hook) remain in effect.
