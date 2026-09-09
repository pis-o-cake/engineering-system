---
name: write-merge-request
description: Write a merge request or pull request body for the reviewer who decides whether to approve it. Use when opening or updating an MR or PR in a project that declares a vcs block.
---

# Write a merge request body

The body is where a reviewer decides whether to approve. It is not a summary of the commit
messages — `git log` already shows those. It gathers scattered commits into one unit of judgement.

Read `merge-request` in `packages/vcs-gov/commit-contract.yaml` under the plugin root for the
required sections and what each one must answer. Read `vcs.merge-request` in the project's
`.engsys/project.yaml` for the target branch. The title follows the same rule as a commit header.

Answer each required section in the declared order, under the heading the contract declares.
Use those headings verbatim — inventing a new phrasing per merge request makes every body read
differently and forces the reviewer to work out the structure again. The section whose heading is
empty carries no heading: it is the opening paragraph.

A section with nothing to report is dropped, not filled with "해당 없음". The excluded list in the
contract names what does not belong.

State the conclusion first. A reviewer who reads only the first paragraph should know what changed
and why. Put the background after it, or leave it out when the change explains itself.

Give the verification section the commands you actually ran and their output — counts and results,
not "테스트 통과". If you could not measure something, write that you could not, and say what would
measure it. Never present an unrun check as run.

Name the trade-off a reviewer would ask about. One line on why the rejected alternative was
rejected costs less than the round trip of them asking.

There is no length limit on the body. Cutting the evidence makes the reviewer read the code again.
Cut repetition instead: a table and a paragraph should not carry the same content.
