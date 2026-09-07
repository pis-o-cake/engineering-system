---
name: verify
description: Run the native verification commands declared by an adopted Engineering System project. Use only when the user explicitly asks to verify the project contract or policy checks.
disable-model-invocation: true
---

# Verify project contract

Run `${CLAUDE_PLUGIN_ROOT}/bin/engsys verify`. It checks the adapter, then runs the project-declared
`commands.verify` and every `documentation.generated` command in order. Report each result. Do not
replace project-native checks with a generic check from this plugin.
