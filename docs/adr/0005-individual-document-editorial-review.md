---
type: adr
id: 0005
status: accepted
date: 2026-09-08
---

# 0005. Documents get editorial review one at a time, and missing reviews are blocked by Git checks

Each document gets an editorial review on its own, judged against its readers, and the native check
and the push gate block missing review receipts and body changes made after review. This check
does not prove sentence quality or approval of a report.

## Problem

Project documents are used not only by developers but also by managers for reporting and
decisions. The existing checks confirm generated output, metadata and links, but they do not filter
out work-log style narration or duplicated or conflicting text. Adding only a style guide gives no
way to confirm that the author read and applied it.

## Decision

`docs-gov` holds editorial criteria keyed to the document's readers and purpose, and the
`review-document` skill. The reviewer reads each document to the end, revises it, then rereads the
final version. The reviewer checks the conclusion, impact and request of a report, the procedure
and verdicts of an operational document, and the structure and constraints of the current
architecture, respectively.

`engsys review record` records one document's hash together with the reviewer, readers, question
and the specific review content. `engsys review check` checks only for missing reviews and body
changes, within the scope the project declares. Generated documents are excluded. The check is
wired into the project's native command, and on push the documents and review receipts of the
commits being sent are checked together.

## Alternatives and Costs

- Automatic verdicts based on banned words or line counts cannot judge whether context and
  evidence are appropriate.
- With only a style guide, changes that skipped review pass.
- Re-reviewing every document with an LLM every time incurs cost even for documents that did not change.

A document whose body changed must be reviewed again, and its review receipt must be committed
with it. When existing documents are first brought into scope, each needs an initial review. They
are not passed automatically in bulk.

## Scope of the Guarantee

The check confirms that a receipt exists and matches the body hash. It does not prove the
truthfulness or independence of the review or the quality of the sentences. An agent's self-review
is recorded as exactly that and is not presented as a manager's approval of a report. The facts
and decisions of existing historical records are preserved. Edits to wording and organization that
the user requested are carried out within that scope, and the current implementation is not
written over past records.
