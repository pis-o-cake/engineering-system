---
description: Classify the current project change against its Engineering System contract. Use before implementing a structural, API, schema, deployment, or documentation change.
---

# Classify change

Read `${CLAUDE_PROJECT_DIR}/.engsys/project.yaml`. If it does not exist, say that the project
has not adopted Engineering System and stop.

Read the current Git diff and only the enabled package policies needed for changed paths. For
Documentation Governance, read `${CLAUDE_PLUGIN_ROOT}/packages/documentation-governance/policy.yaml`.

Return exactly these sections:

1. `Class` — ordinary, data-model, runtime-boundary, API-contract, deployment-boundary, or
   documentation-only. State the evidence path.
2. `Required review` — only the prompt items triggered by the class.
3. `Hard checks` — only commands declared in the project contract.
4. `ADR` — required, consider, or not needed, with one concrete reason.

Do not edit files. Do not infer rationale that is absent from code, project contract, or records.
