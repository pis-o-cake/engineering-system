---
name: bootstrap
description: Bootstrap an Engineering System contract in the current Git project. Use only when the user explicitly asks to adopt or initialize Engineering System.
disable-model-invocation: true
---

# Bootstrap project

Inspect the project before writing. Use the `baseline` profile unless the user names another one.

The `engsys claude` launcher exports `ENGSYS_PLUGIN_ROOT`. If the variable is empty, say the
session was not started through the launcher and stop.

Run `"$ENGSYS_PLUGIN_ROOT/bin/engsys" init --detect --hooks`. Detection fills the native verify
command, source-of-truth directories, documentation paths, lifecycle declarations, and the type
assignments for paths that hold no document yet. Read what it reports. Pass an explicit option only
where detection was wrong or found nothing; explicit options win over detection. It creates these
generated adapter files without installing dependencies or copying this plugin:

- `.engsys/project.yaml` — project name, source-of-truth paths, and native verify command.
- `.engsys/lock.yaml` — resolved profile and package revisions from `system.yaml`.
- `.engsys/generated-paths.txt` — one project-relative generated documentation output path per line.
- `.claude/rules/engineering-system.md` — copy the short route template only when absent.
- `.githooks/pre-push` — with `--hooks`, a project-owned gate; an existing hook or hooks path stays.

Preserve existing `CLAUDE.md`, project policy, and CI configuration. Stop if the project contract
already exists; never overwrite it. Run `"$ENGSYS_PLUGIN_ROOT/bin/engsys" check` after writing.
