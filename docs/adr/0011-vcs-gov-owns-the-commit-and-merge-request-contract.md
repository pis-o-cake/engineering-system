---
type: adr
id: 0011
status: accepted
date: 2026-09-09
---

# 0011. vcs-gov owns the commit and MR conventions; projects declare only values

`packages/vcs-gov` owns the commit message format and the MR body structure, and projects declare
only the subject language, subject ending, scope list and branch model. Enforcement is handled by a
native `commit-msg` hook, because it must also catch a person typing `git commit` directly.

## Decision

- `vcs-gov` holds the commit header format, the type list, the subject length limit, forbidden
  trailers, the blank line after the header, the required MR body sections and the list of branch
  models. These do not change from team to team.
- Projects declare only values in the `vcs` block of `.engsys/project.yaml`:
  `commit.subject-language`, `commit.subject-ending`, `commit.scopes`, `branch.model`,
  `branch.protected`, `merge-request.target`. The shared rules are not copied into projects.
- Enforcement is a native git hook. `engsys init --hooks` installs `commit-msg` together with
  `pre-push`, and `engsys vcs check-message` performs the check. Claude Code hooks are not used
  because they fire only inside a session.
- Only what a machine can judge is blocked. Signals that a commit should be split, such as a
  `·`-separated list, are left as warnings and allowed through.
- The `imperative` ending has no machine rule. The skill and people judge it.
- In v0.1, only the commit message has a native check. The MR body and branch model remain a
  contract that the skill reads.

## Background and Constraints

`public-ai-qa` wrote its commit convention in `CLAUDE.md` and enforced it with a 110-line
`.githooks/commit-msg`. Of the 503 commits accumulated while there was no enforcement mechanism, 31
(6.2%) used the forbidden `…것` ending (a Korean nominalizing ending) and 88 (17.5%) used a `·`
list. That repository measured that a convention without a check is not followed.

That hook is owned by the project, so the next project would have to recreate the same file. The
hook's error messages cite `CLAUDE.md §2` of that repository, so it cannot be moved over as-is either.

There are two constraints. The POSIX sh boundary of
[ADR 0001](0001-posix-sh-core-with-python-tooling.md) is kept. And the subject length must be
counted in characters: Hangul takes 3 bytes in UTF-8, so `wc -m` under the C locale counts a normal
message as three times its length and blocks all of them.

## Rationale and Alternatives

- **Distribute as a Claude Code hook**: it fires only inside a session. It leaks when a person types
  `git commit` in a terminal or another tool creates a commit. Commits are also made outside sessions.
- **Provide only a skill**: it helps with writing but enforces nothing. Both are provided, for the
  same reason as `write-document` and `docs check` in `docs-gov`: the skill covers writing time and
  the hook covers commit time.
- **Have the system decide the subject language and ending too**: this team uses Korean noun-form
  endings, but teams using English imperative are more common. Putting those values in the system
  would keep other teams from adopting it. The boundary between format and values follows the same
  split as the type contract in [ADR 0006](0006-document-type-contract-in-posix-sh.md).
- **Add a suffix rule for `imperative` as well**: built and then discarded. Forbidding `ed` and
  `ing` blocks a valid subject ending in `shared`. Suffixes cannot determine English mood. An
  unverified rule leads people to work around the hook rather than follow the convention.
- **Block `·` lists**: they are not a format violation but a signal that the commit should be split.
  Blocking them would only lead people to remove the list and get through. A warning conveys the
  signal and leaves the judgment to the author.

## Consequences

- A new project gets the commit convention with a single `engsys init --hooks`. Once `scopes` is
  declared, scopes outside the declaration are blocked, so adding a scope means editing the declaration.
- The `commit-msg` a project copied belongs to that project. The standard does not overwrite it later.
- If `engsys` is not on PATH, the commit is not blocked and that fact is reported (for the same
  reason as [ADR 0008](0008-init-detects-declarations-and-seeds-the-project-gate.md)).
- This repository has adopted it as well. After the declaration, the 20 most recent commits were
  checked and all passed.
- The MR body has no native check. A machine cannot catch an MR that breaks the convention. If that
  becomes necessary, it will be considered separately.
- Branch names are checked only when the project declares them in `vcs.branch.naming`. The model's
  `naming` is a default, and without a declaration `engsys vcs check-branch` judges nothing.
  Declaring an untidy list would block valid branches from the first day of adoption.
- `public-ai-qa` can remove its own `commit-msg` and its tests and move to this contract. Commits
  already made are not rechecked.
