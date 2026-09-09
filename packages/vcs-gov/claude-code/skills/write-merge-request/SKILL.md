---
name: write-merge-request
description: Write a merge request or pull request body for the reviewer who decides whether to approve it. Use when opening or updating an MR or PR in a project that declares a vcs block.
---

# Write a merge request body

The body is where a reviewer decides whether to approve. It gathers scattered commits into one
unit of judgement. It is not a summary of the commit messages; `git log` already shows those.

Read `merge-request` in `packages/vcs-gov/commit-contract.yaml` under the plugin root. It declares
the title form, the section headings and their order, what each section answers, the writing rules,
and what does not belong. Ask the project for the target branch instead of assuming one:

```sh
"$ENGSYS_PLUGIN_ROOT/bin/engsys" vcs settings --project <project>
```

It prints the branch model, the merge target, the role branches in promotion order, and the
branch prefixes. Never write a branch name the project did not declare. The same contract applies to a merge request and a pull request.

Use the declared headings verbatim and in the declared order. Do not invent a heading for this
change. Put the detail inside the section it belongs to; add a subsection only when one section
carries two genuinely separate topics.

Write the title in the commit header form: type, optional scope, and the change in one line. No
work log, no self-assessment.

Answer each section with what the reviewer needs and stop. A small change deserves one sentence
per section. Do not pad. A section with nothing to report says 없음 rather than being dropped,
so the reviewer knows it was considered.

Keep what changes a decision even when the body is short: an exception that changes behaviour, a
compatibility break, a trade-off the reviewer would ask about. State the design reason in one
sentence and link the ADR instead of restating it.

Write verification as command and result. Report only checks you ran. If something is unmeasured
and that matters to this approval, say it is unmeasured. Long output belongs in the body only when
it is needed to read a failure.

Prefer the concrete statement over the rhetorical one:

| 대신 | 이렇게 |
|---|---|
| 이번 작업에서 실제로 겪었다 | 재현 조건과 관측한 결과 |
| 새 장치가 아니라 배선이다 | 기존 `resolve_locked_plugin` 을 재사용한다 |
| 옛 revision 의 unknown command 는 버그가 아니다 | 고정 revision 에 없는 명령은 `unknown command` 를 반환한다 |

End with the last section. No generated signature, no tool credit, no promotional line: the body
is the author's, and a trailing badge only adds a line every reviewer skips.

Reread the final body against the final diff before opening or updating. The reviewer must see
what changes, which exceptions exist, and what verified it. Structure and prose are separate
checks; a body that carries every heading can still fail the writing rules.
