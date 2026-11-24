---
type: adr
id: 0003
status: accepted
date: 2026-09-07
---

# 0003. Skills use only the ENGSYS_PLUGIN_ROOT exported by the launcher

Skills that run scripts inside the plugin use only `ENGSYS_PLUGIN_ROOT`, which the launcher exports.
`CLAUDE_PLUGIN_ROOT` is reserved for hook processes and is empty in skills.

## Context

All five v0.1 skills were written to run commands in the form `${CLAUDE_PLUGIN_ROOT}/bin/engsys`.
In fact, `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PROJECT_DIR` are variables that Claude Code injects
**only into hook processes**. When the commands run through Bash as the skill body instructs, this
variable is empty, and the command fails trying to run `/bin/engsys`.

In other words, none of the skills worked, and because the documentation looked correct, the
problem was found late.

## Decision

- Skills that need to run scripts inside the plugin use `ENGSYS_PLUGIN_ROOT`.
- The `engsys claude` launcher exports this variable after it builds the plugin view. The launcher
  also changes to the project root before starting Claude Code, so skills read project files by
  relative path.
- `CLAUDE_PLUGIN_ROOT` is used only in hook commands. Claude Code runs hooks directly, so the
  variable is injected there.
- If a hook-only variable reappears in a skill body, `tests/test-launcher.sh` fails.

## Alternatives

- **Have skills locate the plugin path themselves**: the path inference logic is duplicated in
  every skill body, and skills must know about the plugin view, which varies with the lock.
- **Put `engsys` on PATH and call plain `engsys`**: shorter, but which revision of engsys runs
  varies from session to session. That conflicts with the design of pinning the revision with the lock.

## Consequences

- Skills work correctly only in sessions started with `engsys claude`. If the variable is empty,
  the skill says so and stops.
- Revisit this decision if Claude Code starts exposing the plugin path to the skill execution environment.
