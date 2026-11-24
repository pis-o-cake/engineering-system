---
type: adr
id: 0019
status: accepted
date: 2026-09-09
---

# 0019. A check that could not run is treated as a failure

The push gate and lock-based execution do not pass content that was not checked. This decision
changes the ref skipping and checkout fallback of
[ADR 0013](0013-the-push-gate-judges-the-commit-it-sends.md), and complements the execution pinning
of [ADR 0012](0012-project-commands-run-at-the-locked-revision.md).

## Decision

- The distributed pre-push fails if it cannot find `engsys`, and reports how to activate it.
- `verify --revision` runs for every sent ref except deletions. If the content to be sent differs
  from the working tree, it fails; this repository's own hook uses the same path.
- Even when the lock and the checkout point to the same commit, uncommitted modifications cause
  execution to be handed off to a clean locked worktree.
- If the locked revision or a clean cache cannot be prepared, it fails regardless of whether
  `--revision` is given. It does not fall back to the current checkout.
- Checking this repository itself and an explicit `ENGSYS_USE_CHECKOUT=1` are development
  exceptions. Unit tests use this exception to check the current implementation, and
  version-pinning tests run in an independent Git fixture with the exception turned off.

## Context and constraints

When the launcher was missing, the distributed hook warned and exited 0. It also skipped native checks for refs
other than HEAD. This repository's own hook checked only the tests in the working tree and the
document receipts of the sent commit. So the content that passed the native checks could differ
from the content being sent.

Execution pinning had exceptions too. On the same commit it checked the uncommitted working state, and when
cache preparation failed, a plain verify ran against the current checkout. Printing the standard
revision in the check output did not guarantee that the code of that revision had run.

## Rationale and alternatives

`tests/test-pushed-commit.sh` checks that both hooks fail when the sent content differs from the
working tree. `tests/test-init-detect.sh` covers a missing launcher, and
`tests/test-pinned-execution.sh` confirms that uncommitted modifications on the same commit are
isolated and that a corrupted cache or a missing revision fails.

Leaving only a warning would let work continue in an environment without the tool, but it changes
what passing the gate means. Building a fresh execution environment for an arbitrary commit would
require installing the project's dependencies as well, so within the current scope the check first
confirms that the working tree matches the sent content.

## Consequences

Team members can push only after activating the launcher and preparing the locked revision.
Multiple refs with different content must each be checked out, checked and pushed. Hooks that were
already copied are updated with `engsys hooks update`, and copies the project modified must be
reviewed directly.

This change does not remove the ability to bypass local hooks or the environment dependence of
project native commands. Required checks on the server must be configured separately. Running the
same revision does not mean the same dependencies and external state are guaranteed.
