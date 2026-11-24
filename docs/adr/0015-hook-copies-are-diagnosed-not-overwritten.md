---
type: adr
id: 0015
status: accepted
date: 2026-09-09
---

# 0015. Hooks copied into a project are diagnosed, not overwritten

`engsys hooks status` reports the difference between a project's hook copy and the current
template, and `engsys hooks update` updates it explicitly. Recording both the template the copy is
based on and the copy as of recording distinguishes "just installed" from "modified and maintained
by the project".

## Decision

- `.engsys/hooks.txt` records two hashes per hook: the hash of the template the copy is based on,
  and the hash of the copy at recording time. `init --hooks` and `hooks update` write this record.
- There are five states: `current` (copy = template), `owned` (the project modified it and has
  acknowledged the current template), `outdated` (not modified, but the template changed),
  `modified` (modified, and the template changed afterwards or there is no record), and `missing`.
- `hooks update` updates only `missing` and `outdated` as is. It does not change `modified`
  without `--force`; instead it prints what differs and the two options.
- `--adopt` leaves the copy as it is and records the current template as acknowledged. It reports
  again only when the template changes later.
- `doctor` reports the same states. `upgrade` does not touch hooks.

## Context and constraints

The `pre-push` and `commit-msg` hooks planted by `init --hooks` are owned by the project
([ADR 0008](0008-init-detects-declarations-and-seeds-the-project-gate.md)). It is right that the
standard does not overwrite them, but as a result, projects that had already adopted the standard
had no way of learning about changes to the template.

This repository changed the `pre-push` template twice: the sent-commit verdict
([ADR 0013](0013-the-push-gate-judges-the-commit-it-sends.md)) and the call to the branch name
check. Neither change reached `public-ai-qa`, and the fact that they had not reached it was not
visible either.

The constraint is ownership. If the standard silently reverts a hook the project modified, that
project's checks disappear. This repository's `pre-push` runs its entire test suite, so
overwriting it with the template would remove the gate.

## Rationale and alternatives

- **Have `upgrade` update hooks too**: one command would do everything, but it reverts copies the
  project modified. During implementation it actually overwrote this repository's `pre-push`,
  which was restored with git. Preserving ownership requires updating to be a separate command.
- **Record only the template hash**: the first implementation did this. It could not distinguish
  "just installed" from "modified by the project and kept", so it reported `owned` even when the
  copy had been modified. Two hashes are needed.
- **Print the difference as a diff**: a long hook would flood the screen. The tool prints the
  `diff` command to run, and a person makes the judgement.
- **Write a version into the template**: a copy that edits only that line would drift. A content
  hash is exact.

## Consequences

- Projects that have already adopted the standard have no record, so they first appear as
  `modified`. They either take the current copy as the baseline with `hooks update --adopt` or
  take the template with `--force`.
- The contract directory gains one file, `.engsys/hooks.txt`. The project commits it.
- When the template changes, adopting projects see it in `doctor` and `hooks status`. Each project
  decides whether to apply it.
- `.claude/rules/engineering-system.md` is a copy of the same kind, but it was not included in
  this scope.
