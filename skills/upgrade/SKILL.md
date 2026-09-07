---
description: Plan or apply an explicit Engineering System package upgrade for the current project. Use only when the user explicitly asks to upgrade Engineering System.
disable-model-invocation: true
---

# Upgrade project contract

Read `.engsys/project.yaml`, `.engsys/lock.yaml`, and the system catalog. Compare the locked and
target package revisions.

First return an upgrade plan containing changed packages, generated adapter changes, migration
notes, and native verification commands. Do not write files in this step.

Apply only after the user approves that plan. Change the lock and generated adapter files only;
never modify project source code, project-owned documentation, or `CLAUDE.md`.
