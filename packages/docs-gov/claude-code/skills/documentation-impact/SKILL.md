---
name: documentation-impact
description: Review documentation impact for the current diff using the adopted Engineering System documentation contract. Use when code, architecture, runbook, ADR, design, or generated docs may change.
---

# Documentation impact

Read `${CLAUDE_PROJECT_DIR}/.engsys/project.yaml`, the current Git diff, and
`${CLAUDE_PLUGIN_ROOT}/packages/docs-gov/policy.yaml`.

Classify each affected document as generated output, historical record, current document, or
project guide. Report only affected classes.

- Generated output: name its declared generator or verify command. Never propose a manual edit.
- Historical record: state its lifecycle and whether a new record or annotation is needed. Do not
  rewrite it to match current code.
- Current document: name the current relationship that must be checked.
- Project guide: identify only changed entry points, commands, or ownership links.

Finish with the declared native documentation check. Do not edit files unless the user separately
asked for the change.
