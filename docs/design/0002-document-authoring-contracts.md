---
type: system-design
status: draft
scope: docs-gov-document-authoring
---

# Document Classification and Authoring Standard (Proposal)

Documents are classified by the decision the reader must make and the work the reader must carry
out. Each type defines its body order and required information, and authoring is complete only after
the document passes the structure check and the final review. The starting point is the edited
feature-scope document of `public-ai-qa`.

This document is an adoption proposal. Folder moves, changes to existing policy and checker
extensions are separate implementation work.

## 1. Storage layout

Document type and storage folder are decided separately. Runbooks and verification results need
different authoring rules, but that difference alone does not justify `operations` and
`verification` folders.

As checked on 2026-09-08, public-ai-qa had 2 documents in operations and 2 in verification. dev held
17 documents directly, and meeting held 9. Operations and verification are a handful of shared
documents, while dev mixes scope, schedule, measurements, reviews and server guides. At the current
scale, the layout below is recommended.

| Current folder | Recommendation | Reason and condition for splitting again |
|---|---|---|
| `dev` | Remove and assign each document by purpose | "Written during development" is hardly a criterion readers browse by |
| `operations` | Shared handover documents directly under docs; environment-specific procedures next to infra | Follows the execution target and the owner. Split out when an independent operations team manages runbooks for several services |
| `verification` | Shared criteria and test plans directly under docs; execution results in reports or the relevant spike | Separates criteria that are updated from the results of a specific run. Split out when the criteria and evidence set for repeated acceptance testing grows large |
| `meeting` | Merge into `reports` | Progress reports, meeting records, measurements and reviews are browsed as dated records |
| `mockup` | Move to the relevant frontend | Aligns the owner of the screen code with the owner of its assets and handoff material |
| `adr`, `design` | Keep | Preserves the numbering, baselines and reference boundaries of accumulated decisions and approval records |
| `architecture` | Keep for now | Preserves the canonical paths of the current structure and the generated data model. Not split or merged on document count alone |

A folder is created when there is an independent ownership responsibility or a set of material that
must be browsed together. Folders are not merged just because they hold few documents, nor split just
because the document types differ. A few shared documents can sit directly under docs. When the
number of files grows and browsing actually becomes hard, split by the topics observed.

```text
docs/
  README.md                 document navigation
  documentation-policy.md   project-specific rules
  scope.md                  development scope and done criteria
  wbs.html                  current schedule and assigned work
  handover.md               shared operation, recovery and handover procedures
  kpi-measurement-spec.md    shared KPI measurement criteria
  integration-test-plan.html integration test scope and plan
  adr/                      significant technical decisions
  architecture/             current structure and constraints
  design/                   pre-implementation designs and records as approved
  reports/                  dated report, meeting, verification and review records
    data/                   raw data for those records

backend/README.md           backend development entry point
frontend/<app>/README.md    frontend development entry point
frontend/<app>/DESIGN.md    current UI implementation conventions
frontend/<app>/mockup/      the app's prototypes and handoff material
infra/README.md             infrastructure guide and runbook entry point
infra/devloop/README.md     Windows dev server setup and sync procedure
spike/<topic>/              independently runnable technical experiments
  README.md                experiment purpose, how to run, result links
  YYYY-MM-DD-result.md      results of a specific run
  data/                    input, result and measurement raw data
```

The recommendation is to gather the per-app material in `docs/mockup` into the `mockup` folder of the
relevant frontend. Prototypes of the same app are not managed in two places. A shared location is kept
only when a shared prototype actually exists.

`reports` holds only result and meeting records that have a reference date and a target. It does not
hold current configuration, run instructions, TODOs or verification criteria. File names are
`YYYY-MM-DD-topic.md`, and the authoring differences between reports, meetings, verification and
reviews are expressed through `type`. The document map guides readers by date and topic, and a
detailed version and the report summary built on the same evidence link to each other. Experiment
reports of an independent spike stay next to its run code and are linked from docs.

This tree shows only the authored documents being reorganized. External originals in the existing
`docs/analysis` are preserved where they are.

`design` preserves implementation proposals before approval and their approval records. Descriptions
of current behavior belong in `architecture`. A new design is created only for changes that need prior
agreement; a design document is not added for every simple fix.

### Assignment of existing material

| Current material | Assigned location | Basis |
|---|---|---|
| `01-feature-slices.md`, `02-wbs.html` | `docs/scope.md`, `docs/wbs.html` | Scope and current work are each managed in one file |
| Progress snapshots and meeting records | `docs/reports/YYYY-MM-DD-topic.md` | Preserves the state as of the report or meeting |
| Measurements of performance, cost and citations in production code | `docs/reports/YYYY-MM-DD-topic.md` | Results with an execution time, target and criteria |
| Code and design reviews, reviews of mockup differences | `docs/reports/YYYY-MM-DD-topic-review.md` | Findings, their impact and confirmation of actions |
| Results of independent probes | The relevant `spike/<topic>/` | Run code and experimental evidence kept together |
| `operations/handover.md` | `docs/handover.md` | A shared operations document that also covers agency configuration and personal-data handling |
| `operations/dev-server-windows.md` | `infra/devloop/README.md` | Run scripts and environment procedures managed together |
| The 2 criteria and plan documents in `verification` | Directly under `docs/` with the same names | Separates criteria and plans from measured results |
| Measurement JSON, CSV and originals | `data/` in the same area as the result document | Reproduction and traceability of results |
| Cumulative cost ledger | CSV or data file in the related experiment area | No new prose report for each entry |

When folders move, links, frontmatter paths, check scopes and review receipt paths change together.
Dates, approval status, baselines and raw data are preserved. Same-named files with different content
are compared before assignment.

### Options compared

| Option | Advantages | Cost and assessment |
|---|---|---|
| Keep type-based folders as now | Existing links remain; suits teams that each own a discipline | Even small projects face more location choices, and it overlaps with dev. Not recommended at present |
| Put every document in docs | Simplest location rule | Accumulated decision, design and report records get mixed in, and browsing becomes hard |
| Organize into shared documents, code-adjacent guides and accumulated records | Separates current standards from past records and reduces small classification folders | Requires moves and link cleanup. Recommended at the current scale |

## 2. Common authoring contract

A document is created when there is an explanation to reuse, a scope to agree on, or a judgment or
evidence to preserve. For small code changes and routine test runs, the code, tests and MR record are
enough. One piece of work does not produce a design document, an ADR and an experiment report all at
once. Without independent experiment code, no spike directory is created just to hold a result
document.

Before writing, decide the type, the primary readers and the question the document answers. The type
is recorded in the document's `type`, and the readers and question in the final review receipt. The
first paragraph of the body starts with the actual conclusion, scope or situation of use.

| Rule | Applies as |
|---|---|
| One role per document | Choose one primary purpose among approval, understanding, execution, verification and navigation |
| What stays in the body | The results, evidence, conditions, constraints and procedures the reader needs to judge or act |
| Detail | Put reproduction commands, raw data and long lists in the relevant section or an appendix and link to them |
| Duplication | Manage each figure or explanation in one place. Summaries convey the judgment; details supply the evidence |
| Separating facts | Distinguish observed results, interpretation, proposals and unresolved points in the wording |
| Uncertainty | For unknown values, write what needs confirmation and its impact. Do not guess owners, deadlines, approvals or reasons |
| Omission | Omit optional sections that do not apply. Do not line up empty headings or a stock ‘해당 없음’ (“not applicable”) |
| Completion | Leave a readable finished version and a review receipt. Do not judge document quality by a successful tool run alone |

The required sections of each type below follow the given order. Optional sections are added where
needed. A document that does not answer the questions of its required sections remains a draft. For
facts that cannot be confirmed, state the reason and the effect on the judgment.

### ADR — `decision-record`

- **Readers and question:** Technical leads and maintainers. What was chosen, why, and what cost was accepted?
- **Required order:** decision → context and constraints → rationale and alternatives → consequences.
- **Required content:** The chosen option, its scope, the alternatives actually considered and why they were excluded, constraints and follow-up work. If it is not yet applied in operation, say so.
- **Exclude:** Implementation logs, per-file change lists, hypothetical alternatives that were never considered, current progress percentage.
- **Updates:** After acceptance, a change of decision is recorded in a new ADR. The existing record links to the superseding one.

### Current structure — `architecture`

- **Readers and question:** Developers and operators. Which components operate now, with what responsibilities and boundaries?
- **Required order:** structure summary → components and responsibilities → main flows → constraints and rationale.
- **Required content:** Main dependencies, data and request flows, failure and permission boundaries, implementation locations and links to related ADRs.
- **Optional:** Structure or sequence diagrams when relationships are complex. Generated data models are linked.
- **Exclude and updates:** Do not write debates with past designs, work history or planned features as if they were current fact. Update together with structural changes.

### Pre-implementation design — `design-proposal`

- **Readers and question:** Reviewers and implementers. May this be implemented with this scope and approach?
- **Required order:** proposal summary → goals and out-of-scope → design → verification criteria → open issues.
- **Required content:** Behavior, interface and data contracts, failure handling, reasons for the key choices. If there are no open issues, omit the last section.
- **Conditionally required:** Comparison rationale when choosing between alternatives; compatibility, migration and recovery plans when existing behavior changes.
- **Exclude and updates:** No progress rates or implementation logs. After approval, preserve the scope as approved and link the result documents.

### Project scope — `project-scope`

- **Readers and question:** The project lead and participants. What is delivered, and at what point is it done?
- **Required order:** overall scope → decisions and items to confirm → done criteria per feature. Omit decisions and items to confirm when there are none.
- **Required content:** In-scope and out-of-scope items, dependencies between features, observable completion conditions, the approval basis for scope changes.
- **Optional:** An appendix assigning data and screens. The structure of the approved, edited feature-scope document serves as the example.
- **Exclude and updates:** Exclude SDK usage, per-file code explanations and completion percentages. Preserve the approved scope and link changes as history.

### Work plan — `work-plan`

- **Readers and question:** The project lead and the people doing the work. Who must do what by when, and what is blocking it?
- **Required structure:** baseline date and key milestones → task table → blockers and required actions.
- **Task table fields:** Task ID, deliverable and done condition, owner, due date, status, predecessor tasks, evidence link.
- **Rules:** Mark an unassigned owner as unassigned and an unagreed due date as TBD. Link completion to a deliverable or verification evidence.
- **Exclude and updates:** Do not include design explanations or the full text of completed experiments. Update it as the source of truth for task status and close it when the work ends.

### Brief — `brief`

- **Readers and question:** Senior managers and decision makers. What are the current results and their impact, and what decision or support is needed?
- **Required order:** report summary → key results and impact → decision or support request. Omit the last section when there is no request.
- **Required content:** The report's reference date, which of scope, schedule, quality and cost is affected, and an evidence link for each claim.
- **Conditionally required:** When there is a request: options, the recommendation, the decision deadline and the impact of delay. Do not invent a deadline that is not known.
- **Exclude and updates:** Exclude the debugging process and lists of code identifiers. Preserve the record as of submission and do not duplicate detailed results.

### Meeting record — `meeting-record`

- **Readers and question:** Attendees and follow-up owners. What was decided, and who must do what?
- **Required order:** meeting information → decisions → action items → open agenda items.
- **Required content:** Date and time, attendees and agenda; decisions and their scope; owner and due date for each action. If there are no decisions or actions, say so briefly.
- **Conditionally required:** Summarize only the discussion that explains stakes or the reasons for a decision. Do not record unagreed proposals as decisions.
- **Exclude and updates:** Exclude transcripts in speaking order and re-inclusion of briefs. Preserve confirmed meeting records and record later decisions in new records.

### Verification spec — `verification-spec`

- **Readers and question:** Verifiers and acceptance reviewers. Under what conditions and by what method is pass or fail judged?
- **Required order:** verification scope → test conditions → verdict criteria per item → execution and evidence method.
- **Per-item fields:** Criterion ID, target, inputs and preconditions, procedure, expected result and tolerance, required evidence.
- **Measurement rules:** Specify samples and number of repetitions, denominator and exclusion conditions, units, formulas and statistics. Do not issue a pass verdict on criteria that have not been agreed.
- **Exclude and updates:** Do not mix in execution results or pass thresholds changed after measurement. When criteria are revised, record the version and effective date.

### Verification result — `verification-result`

- **Readers and question:** Reviewers and those accepting the feature. Does this implementation meet the specified criteria?
- **Required order:** verdict summary → target and execution conditions → results per criterion → unmet and unverified items → evidence and reproduction.
- **Required content:** Verification spec version, execution time, target commit and configuration, samples and number of repetitions, expected and observed values, raw data.
- **Verdict:** Distinguish pass, fail, not run and inconclusive. An overall pass requires pass evidence for every required criterion.
- **Exclude and updates:** Do not stretch passing unit tests into deployment readiness or completed acceptance. Preserve re-run results as new run records.

### Experiment report — `experiment-report`

- **Readers and question:** Developers making a technology choice. What was confirmed, and how far does it apply?
- **Required order:** conclusion and applicability → question and success criteria → experiment conditions → results → limitations and follow-up.
- **Required content:** Versions of code, environment and configuration; input samples; number of repetitions; comparison conditions; figures, units and failure cases; links to run commands and raw data.
- **Verdict:** An exploratory experiment may state that it set no success criteria in advance. Do not present criteria created after observation as if they had been set in advance.
- **Exclude and updates:** Exclude long narratives of the order of attempts and assertions about causes that could not be reproduced. Link adoption decisions to an ADR or approval record.

### Code and design review — `review-report`

- **Readers and question:** Fix owners and the responsible lead. Which defects have what impact, and what should be fixed first?
- **Required order:** review summary → target and scope → findings → actions and residual risk.
- **Finding fields:** ID, severity and its reasoning, location, trigger condition and evidence, impact, recommended action, confirmation status.
- **Verdict:** Distinguish confirmed defects from suspicions that need further confirmation. Even when there are no findings, record the scope and limits of the review.
- **Exclude and updates:** Exclude logs of reviewer effort or tool runs, and ‘resolved’ claims without confirmation of the fix. Link the fix and re-review results.

### README — `guide`

A README is the document that lets someone start work at its location. Choose the structure below by
target.

| Target | Required order | Information that must be linked |
|---|---|---|
| Project root | project introduction → getting started → checks → documentation and layout guide | Prerequisites and basic commands, documentation map |
| backend, frontend | role → run → checks → structure and change conventions | Working directory, source of truth for required configuration, main entry points |
| infra | scope of responsibility → source of truth for components and configuration → runbook guide | The environments actually in use and their runbooks |
| spike | experiment question and status → run → results and where they are applied | Dependencies, inputs, commands, result files, where it is reflected in operation |
| Documentation directory | selection guide → document list | Links by question, distinction between current documents and records |
| Data directory | data description → fields and units → reproduction | Source and collection time, distinction between input, original and processed data, transformation commands |

For commands, state the working directory and the result to check on success. Do not add completion
entries to a README for every routine code change. Link full lists of configuration, APIs and
migrations to generated documents or the source of truth.

### Current UI guideline — `ui-guideline`

- **Readers and question:** Frontend developers and designers. By what rules is the current UI implemented and changed?
- **Required order:** scope → screens and states → component and presentation rules → check criteria.
- **Required content:** States and transitions, responsive behavior, the source of truth for shared components and tokens, rules for user-facing text and error handling.
- **Boundary:** Accessibility criteria are managed as a verification-spec and linked from here. Completion claims belong in verification results.
- **Updates:** Update together with changes to the current UI. Even if the file is named `DESIGN.md`, do not confuse it with a design record as approved.

### Prototype and handoff — `prototype-record`

- **Readers and question:** Designers and implementers. Which screens were reviewed, and what does the real implementation need?
- **Required order:** target and version → screens and states → interactions → implementation handoff items.
- **Required content:** How to run or view it, the drafts and their approval status, input, output, error and empty states, and the distinction between real integration and stub behavior.
- **Handoff items:** API connection, removal of placeholder data and prototype-only elements, application of assets, known differences, links to verification results.
- **Exclude and updates:** Do not declare the prototype the source of truth for the current implementation. Preserve real prototype assets and manage them as per-edition records.

### Runbook and handover — `runbook`

- **Readers and question:** Operators. In what situation is it run, how, and how are success and failure judged?
- **Required order:** situation of use → pre-run checks → procedure → success confirmation → failure and recovery.
- **Required content:** Target environment, permissions, inputs and preconditions, commands and expected results for each step, stop conditions, and actions for recovery or for when recovery is impossible.
- **Additional for handover:** Handover recipient and access rights, operational responsibility and contact path, recovery confirmation, remaining work, acceptance criteria.
- **Exclude and updates:** Exclude abstract cautions operators cannot act on and past build logs. Update together with procedure changes.

### Raw data, generated output and external originals

| Nature | Authoring and management rule |
|---|---|
| Experiment and verification raw data | Preserve the original format such as CSV, JSON or logs. Link the run ID and path from the result document |
| Cumulative ledger | Append with fixed fields such as time, target, quantity, unit and cost. Produce summaries when needed |
| Generated document | Declare the generator, the source, and the regeneration and check commands. Change the output only through the generator |
| External original | Record the provider, time of receipt and edition. Do not correct the original; keep interpretation and cross-checking in a separate document |

Markdown and HTML follow the same content contract. For new report HTML, generating it from the
approved manuscript is preferred over duplicating a separate manuscript. Screen prototype HTML is
treated as a prototype asset, not a report. The type and status of a newly authored document are
declared in Markdown frontmatter or HTML metadata. Generated HTML carries the manuscript's metadata,
and prototype assets are managed through the handoff document and asset checks.

## 3. Style and wording

Body text uses the plain declarative Korean endings `~한다` and `~이다` by default. Observations use
`~를 확인했다` ("confirmed that ..."), proposals `~를 권고한다` ("recommend ..."), and unresolved
points `~는 확인이 필요하다` ("... needs confirmation"). Tables and headings may use short noun
phrases.

| Criterion | How to write |
|---|---|
| Sentences | State the actor, action and condition directly. Put one independent claim in each sentence |
| Paragraphs | Answer one question. Split when results, reasons and impact are separate topics |
| Expression | Remove metaphor, exclamation, self-assessment, lecturing and exaggeration meant to persuade the reader |
| Causation | If the cause was not verified, write ‘가능성이 있으며 추가 확인이 필요하다’ (“is possible and needs further confirmation”) instead of ‘원인이다’ (“is the cause”) |
| Technical terms | In briefs, explain in words the reader understands. Keep code identifiers, commands and error names as they are |
| Tables | Use for comparison, assignment and verdicts. One row per item, one attribute per column |
| Lists | Use for steps or parallel items. Do not chop explanations up until every sentence is a list item |
| Emphasis | Limit to conclusions, decision requests and stop conditions. Do not bold the whole body or repeat warning symbols |
| Headings | Instead of ‘남은 것은 이것뿐’ (“all that is left is this”) or ‘조용히 틀리는 것’ (“what silently goes wrong”), preview the content, as in ‘미결 사항’ (“open issues”) or ‘운영 전 확인’ (“pre-operation checks”) |

The project's commit-message rules for noun-form endings and English technical terms are not extended
to document bodies. Each document states its reader standard, connecting it to the documentation style
entry point in the current `CLAUDE.md`.

The figures in the examples below are hypothetical values used only to illustrate style.

| Before | After |
|---|---|
| 뼈대를 얇게 관통시킨 뒤 살을 붙인다 (“run a thin skeleton all the way through, then put flesh on it”) | 실행 환경과 DB 초기화를 먼저 구성한다 (“set up the runtime environment and DB initialization first”) |
| 비용·속도 1차 방어선이다 (“it is the first line of defense for cost and speed”) | 저장 답변은 LLM 호출 없이 반환한다 (“stored answers are returned without an LLM call”) |
| 화면은 정상인데 조용히 틀어진다 (“the screen looks fine but things silently go wrong”) | 기동 후 접근 허용 범위와 정책값을 별도로 확인한다 (“after startup, check the allowed access range and policy values separately”) |
| 이제 남은 것은 발주처 회신뿐이다 (“now all that is left is the client's reply”) | 운영 개시 전 발주처의 허용 IP 대역 확인이 필요하다 (“before operation starts, the client's allowed IP range needs to be confirmed”) |
| 제공자 편차가 원인일 수밖에 없다 (“provider variance has to be the cause”) | 같은 조건에서 처리시간이 달랐다. 제공자 응답시간은 추가 측정이 필요하다 (“processing time differed under the same conditions. Provider response time needs further measurement”) |
| 10회 전부 성공했으므로 안정적이다 (“all 10 runs succeeded, so it is stable”) | 시험한 10회는 모두 성공했다. 장시간 운전과 동시 요청은 미검증이다 (“all 10 tested runs succeeded. Long-running operation and concurrent requests are unverified”) |

Editorial targets are at most 3 sentences for a summary and at most 4 sentences per paragraph, but
they are not used as an automatic pass threshold. Do not meet the length only through line breaks or
sentence splitting, and do not delete required evidence or commands because of the length limit.

## 4. Enforcement design

Enforcement covers the required information per type and the review procedure. Whether sentences are
appropriate and evidence is sufficient is judged by reading the document.

| Stage | Check or handling | Implementation status |
|---|---|---|
| Before writing | Choose the type by path and role; provide only that type's required structure | Per-type rules need to be added |
| Structure check | Block unclassified documents, missing required sections or fields, invalid status, empty required content and broken evidence links | Type and body checks need to be extended |
| Editorial review | Read the whole document from the reader's perspective and fix repetition, evidence, verdicts and style | `review-document` procedure exists |
| Review validity | Confirm that the final body matches the hash in the review receipt | `engsys review check` exists |
| Push check | Check the documents and review receipts of the commits being pushed | Connected in engineering-system; connection in each project needs confirmation |

### What the structure check fails

- A newly authored document within the applicable scope has no valid type or status.
- A required section or field is missing or empty. For conditionally required items, confirm whether they apply and what information they need.
- A verification result claims an overall pass without a criteria version, target or evidence.
- An evidence or raw-data path does not exist, or a generated document differs from its declared source.
- A review receipt is missing or differs from the final body; or re-review was required for a revised authoring rule and the receipt is stale.

Whether a conditional item applies, and natural-language ‘pass’ claims, are not settled by regular
expressions alone. A new verification result carries a structured `result` and per-item verdicts, and
their consistency with the prose is checked in editorial review. Saving a draft is allowed while
unresolved items remain, but missing information needed for the final verdict blocks completion.

### What editorial review rejects

- The opening does not make clear the document's conclusion, scope or purpose of execution.
- A success claim omits failures or exclusions, or generalizes beyond the observed range.
- The same explanation is repeated across sections, or the current conclusion can only be found by reading through the work process.
- Figures, conditions, drawbacks or follow-up actions needed for the decision are missing.
- Facts, alternatives, approvals or owners were made up to fit the document type.

A review receipt records the reviewer, readers, question, body hash and the per-document assessment.
In the extended proposal it also records the applied type and rule version, which are used to decide
re-review after policy changes. Self-review is marked as self-review. The existence of a review
receipt does not prove the quality of the writing or approval of a report.

`CLAUDE.md` links document authoring to choosing a type and reading that type's rules. Actual
completion blocking sits in native checks and Git hooks. Preventing bypass on the server requires
connecting those checks to required CI and merge conditions.

## 5. Adoption and transition

`docs-gov` owns the common types and editorial rules, and a project declares only path assignments,
sources of truth and check commands. No separate skill is created per type; the authoring and review
procedures read the type rules they need. Check items and guidance are managed from a single
declaration so that they never carry different required structures.

1. Define per-type rules and the metadata and status mapping. Existing `type` values are accepted through a mapping table and not changed in bulk.
2. Prepare the assignment list and link change plan for public-ai-qa's dev, operations, verification, meeting and mockup.
   Move after reviewing record boundaries and same-named material.
3. Apply the rules to one document each of scope, README, experiment report, brief and runbook to finalize the examples.
4. Apply the structure check to new documents. For existing documents, manage deferral through a per-file list and convert the files that have actually been reviewed first.
5. If document paths move, also update the native check scope and the review receipts. After implementation, reflect the applied version in the project lock.

New headings or ordering are not enforced in bulk on existing frozen documents. Content changes follow
the existing lifecycle and the owner's editing approval scope. Path changes and style changes are also
reviewed separately, and no blanket ‘exclude all legacy’ rule is defined.

## 6. Implementation done criteria

- Each document is assigned to the location that fits its purpose among shared documents, code-adjacent guides and accumulated records, and its links and check paths are valid.
- New documents of the same type answer the same required questions in the same order. Unrelated empty sections are not generated.
- Check cases exist that fail separately for missing required sections, missing evidence, missing review receipts and body changes after review.
- Check cases exist that enforce the change boundaries of generated documents, external originals and frozen records.
- Reading a brief and an experiment report each, a reader can tell judgment, observation and proposal apart. The reviewer records the actual sentences and evidence.
- The check targets for Markdown, report HTML and prototype assets are distinguished, and missing per-project document paths are detected.

## Sources

- [Existing editorial standard](../../packages/docs-gov/editorial.md): readers and purpose, preserving evidence, final per-document review.
- [ADR-0005](../adr/0005-individual-document-editorial-review.md): the decision on individual review and on blocking missing reviews, and the scope of what it guarantees.
- [Current docs-gov policy](../../packages/docs-gov/policy.yaml): lifecycle, generated-output protection, review receipt checks.
- public-ai-qa material surveyed: `docs/documentation-policy.md`, `docs/README.md`, `docs/dev/01-feature-slices.md`,
  `docs/dev/2026-09-07-index-duration.md`, `spike/hwp2pdf-docker-probe/REPORT.md`, each component README.
