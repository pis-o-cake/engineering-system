---
type: adr
id: 0013
status: accepted
date: 2026-09-09
---

# 0013. The push gate judges the commit it sends

`engsys verify --revision <commit>` first asserts that the checked target is identical to that
commit, then checks it. The default `pre-push` calls it in this form. Previously it checked the
working tree and let a different commit through.

## Decision

- `engsys verify --revision <commit>` first confirms that the working tree is identical to that
  commit. If there are tracked differences or untracked files, it prints what differs and stops.
- `verify` always prints the standard revision it ran with. A run with `--revision` also prints the
  commit it judged.
- The default `pre-push` calls `verify` with each ref's commit to be sent. For a ref that is not
  the checked-out commit, it reports that the ref was not checked. One working tree can be
  identical to only one commit.
- In a run with `--revision`, if the lock revision cannot be fetched, it stops. Only exploratory runs
  without that argument fall back to the current checkout.

## Background and Constraints

`pre-push` ran `engsys verify` against the working tree, and the only check that looked at the
commits being sent was the editorial review receipt check. So when a commit contained content that
would fail and the working tree contained the fix, the gate passed. This was reproduced in a
temporary project: value `bad` in the commit, value `good` in the working tree, `pre-push` result `exit 0`.

[ADR 0012](0012-project-commands-run-at-the-locked-revision.md) pinned the checker's revision, but
the target of the check was still not pinned.

There is one constraint. `commands.verify` and the generated document commands depend on the
development environment. The check command in `public-ai-qa` uses `.venv`, and that directory is
not in the commit. Because of this constraint, checking out an arbitrary commit into a clean
worktree and running the checks there is not an option.

## Rationale and Alternatives

- **Check out the commit being sent into a temporary worktree and check it**: the most accurate,
  but checks that need tools absent from the commit, such as `.venv` or `node_modules`, do not run.
  Preparing that environment is CI's job.
- **Allow push only when the working tree is clean**: the outcome is the same, but it does not say
  why. Showing what differs and stopping is easier to fix.
- **Only warn about the difference and let it through**: the same as now. A gate that passes falsely
  is worse than no gate. Without a gate, people check for themselves; with one, they believe it has
  been checked.
- **Check every ref**: one working tree is identical to only one commit. A ref that could not be
  checked is not reported as checked; the gate reports that fact instead.

## Consequences

- Changes must be committed or stashed before pushing. The workflow of pushing while editing
  documents gains one step. `--no-verify` remains available.
- The meaning of `verify` called without `--revision` does not change. It checks the working tree,
  which is the run needed during development.
- On the gate path, if the lock revision cannot be fetched, it stops. To push offline, fetch that
  revision beforehand.
- When several refs are pushed at once, only the checked-out one is checked. The rest are left to CI.
