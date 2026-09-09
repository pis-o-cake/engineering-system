---
name: write-document
description: Choose a document type and read its contract before creating or restructuring a project document: ADR, design, scope, plan, brief, meeting record, verification spec or result, experiment or review report, runbook, UI guideline, or README.
---

# Choose the type before writing

Decide first whether a document is needed at all. A small code change, a routine test run,
or a single measurement is covered by the code, the test, and the merge request. Do not
create a design, an ADR, and an experiment report for one task, and do not add a spike
directory just to hold a result file.

Then answer three questions before the first line of prose: who reads this, what they must
decide or do, and which type carries that. Read the type's entry in
`packages/docs-gov/document-types.yaml` under the plugin root. That entry is the contract —
readers, question, required metadata fields, and required sections. Read
[editorial criteria](../../../editorial.md) for the writing rules that apply to every type.

The project's `.engsys/project.yaml` assigns paths to types under `documentation.authoring`.
Put the document where its assigned type says, or add the assignment when a genuinely new
location is needed. Do not copy the common type rules into the project.

Create the file with the scaffold rather than typing the form by hand. It fills the metadata,
the filename, and the required headings from the same declaration:

```sh
"$ENGSYS_PLUGIN_ROOT/bin/engsys" docs new --type <type> --project <project> <slug>
```

Write the required sections in the declared order and answer each section's question with
what the reader needs. Omit optional sections that do not apply rather than filling them
with "not applicable". Never invent an alternative, an approval, an owner, or a deadline to
satisfy a field; state the uncertainty and its effect instead. Keep measured values, units,
measurement conditions, failure cases, commands, and source links.

Existing frozen records keep their original headings and order. When you edit one, change
expression and organisation only, and preserve the recorded decisions, dates, evidence,
limits, and approval status.

Finish with the project's document checks and an individual editorial review:

```sh
"$ENGSYS_PLUGIN_ROOT/bin/engsys" docs check --project <project>
```

Then run `/engsys:review-document` on the finished text. A passing structure check is not a
review: it confirms the declared type, metadata, sections, and reference targets, and says
nothing about whether the reasoning or the evidence holds.
