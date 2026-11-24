---
type: adr
id: 0020
status: accepted
date: 2026-09-09
---

# 0020. The project declares platform splits

`commands.verify` and `documentation.generated[].command` are strings the project declares. This
decision settles who determines what runs when such a string differs by OS. It extends the
declaration-location principle of [ADR 0014](0014-projects-name-their-branches.md) to native
commands.

## Decision

- Both keys can declare variants with a `-macos`, `-linux` or `-windows` suffix.
- The default declaration without a suffix remains required. A variant replaces the default
  declaration only on its platform.
- engsys determines the platform with `uname -s`. There is no flag for a person to choose.
- The output prints the key that ran: `Running project verification (commands.verify-windows): ...`.
- `engsys check` rejects any suffix not in the declared list.

## Context and constraints

A Python venv's executables live in `.venv/bin/` on macOS and Linux, and in `.venv/Scripts/` on
Windows. The `verify` of public-ai-qa pointed directly at `.venv/bin/poe` and stopped with
`No such file or directory` on the Windows dev server. The contract was treating one machine's path
as the source of truth.

This split is a language concern, not a concern of the standard. `npm test`, `go test ./...`,
`cargo test` and `./gradlew check` are the same string on both sides. If the standard knew
per-platform commands, that knowledge would soon go stale, so the standard holds only the selection
method and the project holds the values.

## Rationale and alternatives

`tests/test-platform-commands.sh` checks that a variant replaces the default declaration, that a
variant for another platform is not selected, and that a record without a default declaration and
a misspelled suffix both fail.

One alternative is to rewrite the command in a portable form such as `poetry run poe check`. That
takes one line in the contract, but not every project has such a workaround, and when it does not,
this feature would have to be built again.

Using a nested mapping (`verify: {default:, windows:}`) instead of suffixes would make this
repository's POSIX sh parser one level more complex. Suffixes reuse the existing single-line parser
as is.

Making the default declaration optional and declaring only variants would leave nothing to run on
an undeclared platform. In that case the check must fail rather than pass silently, so the default
declaration stays required.

## Consequences

Existing contracts keep working as they are. Without declared variants, the selection always
resolves to the default declaration.

Because keys under `commands` are now checked, a project that put a command under another name in
that block is rejected by `check`. No such project exists at present.

Running the same revision does not mean the same dependencies
([ADR 0019](0019-verification-fails-when-it-cannot-run.md)). Platform variants only align command
paths; creating the venv or toolchain on that machine is still the project's job.
