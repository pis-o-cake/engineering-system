---
type: decision-record
id: 0023
status: accepted
date: 2026-09-10
---

# 0023. The standard is distributed as a plugin marketplace

The project declares the marketplace and plugin in `.claude/settings.json` and commits that file.
However Claude Code is opened (CLI, desktop app or IDE extension), the skills and hooks attach.
`engsys claude` remains as the strict path, used when the skills must also match the lock revision.

## Decision

- The standard repository holds `.claude-plugin/marketplace.json`. This repository is itself the
  marketplace.
- `engsys init` writes `extraKnownMarketplaces` and `enabledPlugins` into the project's
  `.claude/settings.json`. The coordinates come from the `origin` of the standard checkout. If the
  origin is not on GitHub, it writes only the hooks and reports what must be written by hand.
- The project owns this file. If it already exists, it is not overwritten.
- `engsys claude` remains as a reproduction mode. It is used when the skills and hooks must also be
  those of the lock revision: to revisit a project locked to an old revision with the guidance of
  that time, or while working on the standard itself. It is not the default path for everyday work.
- `doctor` reports whether the project has this declaration and whether the `engsys` that the
  declaration relies on is on PATH.
- This document reverses the rejection of marketplace distribution in the "Rationale and
  Alternatives" section of
  [ADR 0007](0007-one-command-activation-and-main-as-release-channel.md). The rest of that
  document's decisions stand: developer activation through a single `install.sh`, the diagnostic
  scope of `doctor`, and `origin/main` as the release channel.

## Context and constraints

The skills and hooks live in one place, the standard repository, and copies do not scatter. The
problem was the point of delivery. They attached to a session only when `engsys claude` passed them
via `--plugin-dir`, so the same repository produced different results depending on how the session
was opened ([ADR 0022](0022-a-declared-contract-needs-a-gate-not-an-instruction.md)).

The desktop app and IDE extensions have no entry point equivalent to `engsys claude`. Their users
had no way at all to attach the standard.

ADR 0007 considered and rejected this approach. The reason was: "A marketplace pins plugin versions
per developer, while this system pins per project. The two pinning axes conflict." That judgement
rested on the premise that the plugin carries the verdict code. The actual structure is different:
the plugin carries skills and hook wiring, and the verdict is made at the lock revision by the
`engsys` that the hooks call. Only one axis conflicts, and that is the guidance text.

The constraint is the pinned execution defined by
[ADR 0012](0012-project-commands-run-at-the-locked-revision.md). The marketplace tracks a branch,
so skills and hook wiring come from `main`. The verdict, however, stays pinned: all a hook does is
call `engsys`, and `engsys` re-executes itself at the lock revision. What can drift is the guidance,
not whether a check passes.

## Rationale and alternatives

- **Copy the skills into each project's `.claude/skills/`**: this makes them independent of the
  session, but the number of copies grows with the number of projects. Every fix to the standard
  would have to be pulled by each project separately.
- **Keep only `engsys claude`**: pinned execution stays complete, but desktop app users remain
  excluded. In everyday work a project is rarely locked to an old revision, and even then the
  verdict stays pinned.
- **Pin the marketplace to a specific revision**: the declaration format assumes branch tracking.
  For cases that need pinning, `engsys claude` is already the answer.

## Consequences

- A team member's path ends at `clone` followed by opening the project. There is no skill
  installation procedure.
- Because skill text comes from `main`, guidance and verdict can disagree in a project with an old
  lock. The verdict wins, and when it rejects, it prints the declared values as well, so the author
  sees the correct answer on the spot.
- If the standard's `origin` is not on GitHub, the declaration cannot be written automatically.
  `init` reports that.
- `engsys` must still be present on each machine. The plugin carries hook wiring and skills, not the
  code that makes verdicts. The declared hooks look up `engsys` on PATH, so without it the gate does
  not run. `doctor` reports that state, and `pre-push` blocks the push.
