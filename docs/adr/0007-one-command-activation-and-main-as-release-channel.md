---
type: adr
id: 0007
status: accepted
date: 2026-09-08
superseded-in-part-by: 0023
---

# 0007. Activation is a single install script, and the release channel is origin/main

A team member's activation is reduced to a single run of `./install.sh`, and `engsys doctor` reports
whatever is missing together with the command to run. The standard's release channel is
`origin/main`, and the lock records the revision of the checkout that ran the command.

## Decision

- Developer activation is `install.sh` alone. It changes only one line in the developer's own shell
  profile and `core.hooksPath` of this clone, and writes nothing to projects that adopt the
  standard. Running it twice gives the same result, and if the profile points to a different
  checkout, it reports that line instead of overwriting it.
- Diagnosis is `engsys doctor`. It reports the system checkout revision, the PATH link, push gate
  registration, whether the contract and lock pass `engsys check`, availability of the locked
  revision, and the difference from `origin/main`. If there is a fixable problem it exits 1, and it
  prints the command to run for each item.
- The release channel is `origin/main`. To pin a specific release, check out its tag and then run
  `upgrade`. The lock always records the revision of the checkout that ran the command.
- `doctor` warns, rather than counting it as a failure, when the lock is unreachable from
  `origin/main`. This avoids blocking the workflow of locking to one's own branch revision while
  changing the standard.

## Background and Constraints

Activation in v0.1 had three steps: clone, add `eval "$(... shellenv)"` to the shell profile, and
`git config core.hooksPath .githooks`. Every team member had to repeat them, and nothing reported
an omission. A missing hook registration is especially silent. With no CI runner,
`.githooks/pre-push` is this repository's only gate (separate from the approximate check in
[ADR 0002](0002-contract-schema-is-canonical.md)), so a developer who did not register it pushes
with no checks at all.

`system.yaml` declared release delivery as `private-marketplace`, but there was no implementation.
The way team members actually got the standard was "share the path to my local clone".

The constraint is the same as in [ADR 0001](0001-posix-sh-core-with-python-tooling.md). To avoid
raising the adoption cost, `install.sh` is also dependency-free POSIX sh.

## Rationale and Alternatives

- **Distribute through the Claude Code plugin marketplace**: activation gets even shorter. But the
  marketplace pins plugin versions per developer, while this system pins per project (the structure
  in which the launcher from [ADR 0003](0003-skill-uses-launcher-environment.md) assembles the
  plugin view from the lock revision). The two pinning axes conflict, so it is not used in v0.1.
- **Provide guidance in documentation only**: this is the approach so far. Nothing checks for
  omissions, so there is no way to discover an unregistered hook.
- **Have `doctor` fix the problems it finds automatically**: it looks shorter, but it would change
  the shell profile silently. Diagnosis and repair are separated, so repair happens only when the
  developer runs `install.sh`.
- **Add `upgrade --to <tag>`**: considered and left out this time. It would need to read the
  target revision's package version and profile from that revision, but the current implementation
  reads them from the working tree. Checking out and then running `upgrade` gives the same result,
  so the risk of reading the wrong values is not introduced now.

## Consequences

- A team member's activation is two steps: clone and `install.sh`. `engsys doctor` reports anything missing.
- `install.sh` adds two lines to the developer's shell profile. To undo it, delete those lines.
- If the lock is placed on a revision that has not been pushed, team members' clones cannot fetch
  that revision. `doctor` warns but does not block.
- `upgrade` still records the checkout revision of the developer who ran it. For the team to use the
  same revision, the checkouts must be aligned first. If this manual step causes real problems,
  revisit `--to`.
