---
type: adr
id: 0018
status: accepted
date: 2026-09-09
---

# 0018. Adoption proceeds step by step, with confirmation at each step

`engsys setup` splits adoption into steps; at each step it checks the current state, shows what it
will change, and runs only after getting consent. Other commands stay non-interactive.
`engsys init --dry-run` produces that preview.

## Decision

- Add `engsys setup`. It has seven steps: prerequisite tools → system checkout → developer
  activation → target project → Git hooks → checks → what remains. Each step prints its check
  results first.
- A step that changes files shows what it will change and then asks. Contract generation shows the
  output of `init --dry-run` as is and asks for consent.
- `--yes` approves every step. With no terminal and no `--yes`, it does not start. Proceeding when
  it cannot ask would amount to declining everything, and that fact would not be visible.
- Other commands are not made interactive. `init`, `verify` and `hooks` are called by CI and
  scripts.
- The final step runs `doctor` once more. An intermediate step may have only warned and moved on,
  so if problems remain, it does not finish as a success.
- On failure, it prints again at the end the step where it stopped and the next command to run,
  and saves the full output to a file. A single printed line would vanish once the terminal is
  closed, and it would not say what needs fixing.
- `setup` can be run more than once. It does not regenerate an existing contract, and it does not
  overwrite hooks the project modified.

## Context and constraints

Adoption was three commands: `install.sh`, `engsys init --detect --hooks` and `engsys doctor`. Each
command finished in one go, and what happened was visible only after running it. Someone attaching
the system for the first time had no point at which to stop or confirm.

The constraint is automation. These commands are also called from CI and scripts. Making them
interactive would break that path.

## Rationale and alternatives

- **Make `install.sh` and `init` interactive**: the number of commands would not grow, but they
  could no longer be used in CI. Guidance lives in a separate entry point, and existing commands
  stay as they are.
- **Extend `doctor` to fix things**: there is already a decision that `doctor` only diagnoses
  ([ADR 0007](0007-one-command-activation-and-main-as-release-channel.md)). Putting diagnosis and
  change in one command blurs what was changed.
- **Describe the procedure only in documentation**: this was the approach until now. Nothing
  confirms that the order was followed or that each step finished.
- **Proceed with defaults when it cannot ask**: the result is the same as declining everything, and
  the user reads it as success. It does not start and states why.

## Consequences

- Someone adopting for the first time only needs to know `engsys setup`. Each step's command is
  visible as is in the output.
- `init --dry-run` now exists, so the detection result can be checked before a contract is
  created. It is also used outside `setup`.
- `setup` does not automatically declare document type assignments or editorial review scope. The
  final step only reports what needs to be done. A person decides those declarations after looking
  at the actual documents.
- `docs check`, which used to fail when none of the assigned paths existed yet, now warns instead.
  A new project passes the check even before it creates a README. A machine cannot tell a stale
  declaration from a path that has not been created yet, so it reports rather than blocks.
