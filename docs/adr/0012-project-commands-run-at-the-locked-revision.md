---
type: adr
id: 0012
status: accepted
date: 2026-09-09
---

# 0012. Project commands run at the revision the lock points to

The `engsys` on PATH acts as the entry point, and the code that checks a project is taken from the
revision that project's `lock.yaml` points to. Until now only `engsys claude` looked at the lock,
and every other command ran from the checkout of the developer who invoked it.

## Decision

- `check`, `sync`, `verify`, `docs`, `review` and `vcs` hand execution over to the target project's
  lock revision. The worktree for that revision reuses the cache that `engsys claude` already used.
- Four commands are not handed over. `init` has no lock yet; `upgrade` changes the lock, so the new
  code has to run; `doctor` diagnoses the version difference itself; and `claude` already uses the lock.
- If the lock revision equals the commit of the current checkout, execution is not handed over.
  Changes in the working tree do not change the revision, so someone changing the standard can
  still check with their own changes.
- If the target is the system repository itself, execution is not handed over. With
  `ENGSYS_USE_CHECKOUT` set, it is not handed over in any project.
- If the lock revision cannot be fetched, work is not blocked. The fact is reported and the command
  runs from the current checkout.

## Background and Constraints

`.engsys/lock.yaml` had pinned a revision since v0.1, but only `engsys claude` read it.
`engsys docs check` typed in a terminal and `engsys vcs check-message` called from a Git hook ran
from the checkout of whoever invoked them.

So two people checking the same project could get different results. In fact, while this standard
was being developed, the document check for `public-ai-qa` ran with the checker from a branch that
had not yet been merged. That result is not the verdict of the standard the lock points to.

The constraint is the distribution path set by
[ADR 0007](0007-one-command-activation-and-main-as-release-channel.md). A release is a commit on
`origin/main`, and a project writes one of them into its lock. The way to fetch that commit already
exists in `resolve_locked_plugin`.

## Rationale and Alternatives

- **Leave it as it is and do not read the lock**: each developer gets different results. If there is
  a lock but most commands ignore it, the pinning exists in name only.
- **Hand over every command**: if `upgrade` runs at the old revision, it cannot upgrade itself to
  the new revision. `doctor` reports the difference between the checkout and the lock, so handing
  it over would make that difference invisible.
- **Hand over when the working tree is dirty**: this is how `resolve_locked_plugin` originally
  decides. But then a person changing the standard cannot check with their own changes. The chosen
  option is not to hand over when the revisions are equal.
- **Stop at a revision that cannot be fetched**: with no network, or with a revision that has not
  been pushed, every check would stop. A gate that cannot explain why it blocked gets deleted (the
  same judgment as [ADR 0008](0008-init-detects-declarations-and-seeds-the-project-gate.md)). It
  reports and proceeds.

## Consequences

- Project check results are the same regardless of which branch a team member has checked out.
  The only way to raise the standard version becomes `engsys upgrade --apply`.
- In a project pinned to an old revision, a command that does not exist at that revision ends with
  `unknown command`. That means the project has not yet adopted that convention, so it is the
  correct behavior. Project Git hooks already let that case through.
- The first run incurs a one-time cost of creating the worktree for the lock revision. Later runs
  use the cache.
- Nothing changes when changing the standard in this repository. When the target is itself,
  execution is not handed over.
