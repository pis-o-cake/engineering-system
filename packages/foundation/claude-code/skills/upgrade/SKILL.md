---
name: upgrade
description: Plan or apply an explicit Engineering System package upgrade for the current project. Use only when the user explicitly asks to upgrade Engineering System.
disable-model-invocation: true
---

# Upgrade project contract

Run `"$ENGSYS_PLUGIN_ROOT/bin/engsys" upgrade` and return its plan — the `engsys claude` launcher
exports this variable. Do not write files in this step.

Apply only after the user approves that plan by running `"$ENGSYS_PLUGIN_ROOT/bin/engsys" upgrade
--apply`. It changes the
lock only; never modify project source code, project-owned documentation, or `CLAUDE.md`.
