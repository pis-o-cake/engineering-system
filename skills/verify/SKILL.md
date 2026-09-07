---
description: Run the native verification commands declared by an adopted Engineering System project. Use only when the user explicitly asks to verify the project contract or policy checks.
disable-model-invocation: true
---

# Verify project contract

Read `.engsys/project.yaml` and `.engsys/lock.yaml`. Confirm both exist before running anything.

Run the declared `commands.verify` command. Then run every generated document command declared in
`documentation.generated`. Report each command and result. Do not replace project-native checks
with a generic check from this plugin.
