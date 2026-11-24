---
type: decision-record
id: 0025
status: accepted
date: 2026-09-10
---

# 0025. The gate travels with the plugin, not the PATH

The merge request gate is registered by the plugin's hook catalog, not by the project's
`.claude/settings.json`. The hook locates itself through `${CLAUDE_PLUGIN_ROOT}` and finds the
`engsys` that makes the verdict in the same place. PATH is the last candidate.

## Decision

- `packages/vcs-gov/package.yaml` declares a `PreToolUse` / `Bash` hook, and the catalog registers
  it as `sh "${CLAUDE_PLUGIN_ROOT}/..."`.
- The hook looks for the launcher in the order `ENGSYS_SYSTEM_ROOT` → `CLAUDE_PLUGIN_ROOT` → PATH.
  If it finds none, it does not let the call through and returns that fact.
- The project's `.claude/settings.json` holds only the marketplace and plugin declarations. The hook
  entry is removed.
- Of the decisions in [ADR 0022](0022-a-declared-contract-needs-a-gate-not-an-instruction.md), this
  document supersedes only the file that registers the gate. "What calls the gate is a declaration
  stored in the repository, not a skill the session read" still stands: that declaration is
  `enabledPlugins`, and the plugin carries the gate.

## Context and constraints

ADR 0022 registered the gate as a hook in `.claude/settings.json`. The command was
`engsys vcs merge-request-hook`, which rested on the premise that `engsys` is on PATH.

On 2026-09-10 that premise broke on Windows. Claude Code calls hooks outside a login shell, and Git
Bash's activation line exists only in the login profile. Every Bash call produced the following.

```
PreToolUse:Bash hook error
Failed with non-blocking status code: /usr/bin/bash: line 1: engsys: command not found
```

Because the failure was non-blocking, the commands ran anyway. In other words, **the gate ran
switched off**, and every call only printed an error. The rule set by
[ADR 0019](0019-verification-fails-when-it-cannot-run.md), "a check that could not run is a
failure", does not hold at the point where the hook itself dies. The answer is to not create that
point.

The constraint is the path. `.claude/settings.json` is committed by the project, so it cannot use an
absolute path on a developer's machine, and `${CLAUDE_PLUGIN_ROOT}` is provided only to hooks the
plugin registers. The plugin is already attached through that file's declaration
([ADR 0023](0023-the-standard-ships-as-a-plugin-marketplace.md)).

## Rationale and alternatives

- **Plant `engsys` on the system PATH**: on Windows this would mean touching PATH outside the login
  shell, and it crosses the boundary set by
  [ADR 0007](0007-one-command-activation-and-main-as-release-channel.md) that `install.sh` edits only
  the developer's shell profile.
- **Wrap the hook command in `bash -lc`**: it would read the login profile, but the hook would then
  carry a shell name, and developers with heavy profiles would pay that cost on every Bash call.
- **Register in both settings.json and the catalog**: it would still run if either were missing, but
  with both active the same body is judged twice and the rejection message appears twice.
- **Make hook failures blocking**: this is not something this repository can decide. Claude Code
  treats hook errors as non-blocking.

## Consequences

- The gate runs in sessions where the plugin is attached. The plugin is attached through a
  declaration the project commits, so it remains independent of how the session was opened.
- Projects that already received the hook entry in `.claude/settings.json` delete it. If it stays,
  the same verdict runs twice, and machines without `engsys` on PATH keep printing errors.
- When working on the standard itself, `engsys claude` passes the plugin of the lock revision, so
  that revision's gate runs. On the everyday path, the gate from `main` delivered by the marketplace
  runs.
- If `engsys` cannot be found anywhere, the gate rejects. `engsys doctor` reports that state as a
  failure.
