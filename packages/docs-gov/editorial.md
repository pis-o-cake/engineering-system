# Document editorial criteria

A reader must be able to make the needed judgment or do the needed work from the document alone.
Before writing, decide who the reader is and what question the document answers. Match the length
to the evidence and procedure that question needs.

| Document | What to tell first | What must remain |
|---|---|---|
| Reports and decision material | Conclusion, business and schedule impact, the decision or support requested | Evidence, options and their costs, undetermined items, next actions |
| Current architecture | Current structure and major constraints | Boundaries, relationships and flows, the implementation's source of truth, links to decision records |
| Operating procedures | When it applies and its preconditions | Execution order, success verdict, actions and recovery on failure |
| Design and ADR | The problem and the decision chosen | The rationale at the time, the alternatives actually considered, costs and constraints |
| Experiment and review records | Time of observation, conclusion and applicability | Reproduction conditions, measured values, location of evidence, limitations |

Write the body of report material so that a superior who did not take part in development can
understand it. Keep code identifiers and commands unchanged, and spell out the technical terms used
in explanations as far as the reader needs. Place technical detail in an evidence section or an
appendix. If there is no decision to request, do not invent an approval item.

## What to check while editing

- Does the first paragraph show the result or the key state? Do not declare the document's nature at length.
- Does each section answer the reader's question? Remove work order, conversation rounds and back-and-forth with the user from the final explanation.
- Are facts, interpretations, proposals and undetermined items kept apart? Do not generalize observations without evidence or overstate success.
- Is the same explanation repeated across a table, the body and a summary? Instead of repeating, gather the content in one place and link to it.
- Is an old explanation or a correction sentence left behind after an explanation was already fixed? Record documents distinguish the state at each point in time.
- Do bold text, warnings, parentheses or arrows stand in for the relationship between sentences? Keep only the emphasis needed for a judgment.
- Do metaphors, self-assessment, lecturing or dramatic contrasts get in the way of conveying facts? Replace them with concrete states and results.
- Did shortening lose decision reasons, numbers, units, conditions, counterexamples, commands or sources?

Do not decide a pass by line count or by the number of banned words. Use a table when there are
items to compare, and a list when there are items to check or run side by side. Write the
necessary explanation as connected sentences.

## Rewriting examples

The examples quote Korean text because adopting projects write their documents in Korean. Each
quote is followed by an English rendering.

In an operating procedure, the statement “무엇이 조용히 틀리는가에 지면을 쓴다. 화면은 정상이고
로그도 조용하다” ("This spends its pages on what goes wrong silently. The screen looks normal and
the logs are quiet.") is rewritten as “이관 전에 프롬프트 초기값, 접근 허용 범위, 프록시 IP 설정을
확인한다. 기동 성공만으로는 이 설정들의 정확성을 확인할 수 없다” ("Before migration, check the
prompt defaults, the allowed access range and the proxy IP settings. A successful startup alone
does not confirm that these settings are correct."). Then write the actual check commands and the
expected results.

In a current architecture document, the statement “문서가 오래 자급자족이라 적어 왔으나 코드는
그렇지 않다” ("The documents long described it as self-sufficient, but the code is not.") is
rewritten as “도메인 사이에 순환 의존성이 있어 개별 도메인을 그대로 분리할 수 없다” ("There are
circular dependencies between domains, so an individual domain cannot be split out as it is.").
Describe the confirmed relationships and constraints, and link the process of investigating the
errors in past documents to a review record.

In a report, “대공사·세션 최대 규모 리팩터” ("a major overhaul, the largest refactor of the
session") is not grounds for a report. Write the actual scope of the change, the reason for it, the
verification results and the remaining risks. Do not add cost savings or quality improvements that
were not measured.

## Completion conditions

Read each written or revised document to the end, one at a time, and edit it against the criteria
above. For the final content, record the reader, the question, concrete review findings and the
body hash. If an unresolved contradiction or an unsupported conclusion remains, do not record a
pass. Do not edit the bodies of generated documents or external originals directly.

Missing reviews and changes after review are checked by the native gate. This check does not prove
the quality of the writing or the reviewer's independence. Responsibility for approving reports and
judging facts stays with the existing reviewers.
