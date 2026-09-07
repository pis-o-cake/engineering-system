---
description: Bootstrap an Engineering System contract in the current Git project. Use only when the user explicitly asks to adopt or initialize Engineering System.
disable-model-invocation: true
---

# Bootstrap project

Inspect the project before writing. Use the `baseline` profile unless the user names another one.

Create these generated adapter files without installing dependencies or copying this plugin:

- `.engsys/project.yaml` — project name, source-of-truth paths, and native verify command.
- `.engsys/lock.yaml` — resolved profile and package revisions from `system.yaml`.
- `.engsys/generated-paths.txt` — one project-relative generated documentation output path per line.
- `.claude/rules/engineering-system.md` — copy the short route template only when absent.

Preserve existing `CLAUDE.md`, project policy, and CI configuration. Show the complete planned diff
before writing if any target already exists. Validate the manifest against
`${CLAUDE_PLUGIN_ROOT}/schemas/project.schema.json` after writing.
