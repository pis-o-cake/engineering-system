---
name: review-document
description: Edit and review one authored project document for its intended readers before reporting documentation work complete. Use for reports, architecture, guides, and runbooks; exclude generated outputs.
---

# Review a document

Read the whole document, the project documentation policy, and
[editorial criteria](../../../editorial.md). For a long document, read consecutive sections
until all content is covered. Search results, headings, and automated scores are not a review.

Work on one document at a time. Identify its readers and the question it must answer before
editing. Reports may be read by managers who were not present during development. Explain
decisions, evidence, consequences, and requested action without assuming the author's chat history.
Preserve the document's intended format; do not turn every technical reference into a report.

Respect existing edits and lifecycle. Do not update historical facts to today's implementation.
An explicit request for editorial cleanup permits changes to expression and organization while
preserving the original decisions, dates, evidence, limitations, and approval status. Do not infer
missing rationale. Preserve external source documents and generator-owned outputs.

When editing is authorized, revise the document itself. Resolve repeated or conflicting paragraphs
using the recorded evidence. If a contradiction cannot be resolved, expose the uncertainty and
do not issue a passing review. Keep commands, measured values, and source links that readers need.

After editing, reread the entire result as a reader who did not see the work. Check the criteria
and the diff for lost evidence. Run the project's relevant link, generator, or document checks.
Do not equate shorter text, valid metadata, or passing tests with editorial quality.

Record a pass only after that review, with document-specific observations: what its conclusion
is, which evidence supports it, what was changed or already adequate, and any stated limitations.
No generic "checked all criteria" notes, batch approvals, or fabricated reviewer identities.
Use your actual agent identity; do not call a self-review independent or human-approved.

The launcher exports `ENGSYS_PLUGIN_ROOT`. Use its CLI to inspect the final blob and record it:

```sh
"$ENGSYS_PLUGIN_ROOT/bin/engsys" review status --scope docs/report.md
"$ENGSYS_PLUGIN_ROOT/bin/engsys" review record --document docs/report.md \
  --blob <hash-from-status> --reviewer <actual-reviewer> \
  --audience <intended-readers> --purpose <question-answered> --notes-file <review-notes>
```

The notes file contains your review observations, not the document body. If the document changes
after review, review the changed result before recording its new hash. Keep the receipt with the
document's change. Never produce a pass just to unblock a gate.

Finish with reviewed paths, material edits, and unresolved issues. For multiple documents, repeat
this process separately and report incomplete reviews honestly. Do not create additional reports
about the editing process unless requested; the review receipt is sufficient.
