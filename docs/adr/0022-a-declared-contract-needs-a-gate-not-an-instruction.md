---
type: decision-record
id: 0022
status: accepted
date: 2026-09-10
superseded-in-part-by: 0025
---

# 0022. A declared contract needs a gate, not an instruction

`engsys vcs check-merge-request` judges the merge request body, and a PreToolUse hook in the
repository's `.claude/settings.json` calls it before `gh pr create`. The skill only explains how to
write the body; it does not enforce anything.

## Decision

- In the `merge-request` section of `packages/vcs-gov/commit-contract.yaml`, the values a machine
  can judge are separated out: `section-heading-prefix` and `forbidden-body-contains`. The remaining
  `writing` and `excluded` items are checked by people.
- `engsys vcs check-merge-request <file> [--title <text>]` judges the presence and order of section
  headings, headings outside the declaration, empty sections and forbidden phrases. `--title` reuses
  the commit header checker as is.
- `engsys vcs merge-request-hook` reads the Claude Code PreToolUse payload and intercepts
  `gh pr create` and `gh pr edit`. It takes the body through `--body-file`. It blocks inline
  `--body` and `gh pr create` without a body. A body that could not be read has not been judged
  ([ADR 0019](0019-verification-fails-when-it-cannot-run.md)).
- `init` leaves `.claude/settings.json` in the project. What calls the gate is this file, not a
  skill the session happened to read.
- A project that does not declare `vcs.merge-request` is not judged.

## Context and constraints

The `merge-request` section was declared in
[ADR 0011](0011-vcs-gov-owns-the-commit-and-merge-request-contract.md) with the same authority as
the `commit` section. But `commit` had the `commit-msg` hook and `engsys vcs check-message`, while
`merge-request` had no code that judged it. The only thing that kept the contract followed was the
`/engsys:write-merge-request` skill.

On 2026-09-10, PRs #20, #21 and #22 in this repository were opened in that state. All three bodies
used section headings outside the declaration and ended with an auto-generated signature that
`excluded` forbids. Merge requests opened in `public-ai-qa` during the same period followed the
contract. The difference was not the person or the repository but how the session was opened:
sessions opened with `engsys claude` had the skill attached, and sessions opened with plain
`claude` did not.

The skill exists in one central place. The problem is not scattered copies but the point of
delivery. And even when attached, a skill is an instruction, so nothing happens if it is not
followed. Commit messages are followed not because a skill exists but because a hook blocks them.

The constraint is where the body is stored. A merge request body is not in git. There is no point
at which a git hook can block it as with a commit message, so it has to be blocked where the body
is created.

## Rationale and alternatives

- **Strengthen the skill's wording**: this only raises the force of the instruction. If the session
  does not read it, the force is meaningless.
- **Register only in the plugin hook catalog**: it runs only in sessions opened with
  `engsys claude`, leaving the current problem in place. Only a setting stored in the repository is
  independent of how the session was opened.
- **Search the command string for `gh` as text**: the first implementation did this, and the commit
  message describing this gate tripped over the gate itself. Its body merely contained the
  characters `gh pr create`. Now heredoc bodies are stripped and only a `gh` in command position is
  considered.
- **Parse and judge inline `--body` as well**: shell quoting would have to be undone, and a
  heredoc's boundaries cannot be determined from the payload. Allowing a form that cannot be judged
  invites bypassing through that form. Requiring a file makes the body diffable and easier to
  review again.
- **Check the PR body in CI**: once server checks exist, this is right as a second line of defense.
  This repository has no server CI today, and blocking a body before it is opened is better than
  learning about it after it was opened wrong.

## Consequences

- `gh pr create` requires `--body-file`. Writing the body to a file adds one step, and that file
  remains available for review.
- People who do not use Claude Code do not pass through this gate. The verdict can be invoked
  directly with `engsys vcs check-merge-request`, and server checks, once they exist, use the same
  command.
- Projects that have already adopted the standard have no `.claude/settings.json`. They rerun
  `init` or copy it from the template. The project owns this file, and the standard does not
  overwrite it.
- The verdict covers section headings, order, empty sections, forbidden phrases and title format.
  The style and redundancy rules in `writing` are not judged by a machine, so reviewers keep checking
  them.
