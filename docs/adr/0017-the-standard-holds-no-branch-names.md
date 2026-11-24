---
type: adr
id: 0017
status: accepted
date: 2026-09-09
---

# 0017. The standard holds no branch names

`branch-defaults` is removed. The project declares branch names and prefixes, and when it does not,
tools give no answer. This supersedes the defaults decision in
[ADR 0014](0014-projects-name-their-branches.md).

## Decision

- `branch-defaults` is deleted from the contract. No names such as `develop`, `main` or `feat/`
  remain in the standard.
- If `vcs.branch.model` is declared but `roles` is not, `engsys vcs check-settings` reports what
  needs to be declared and fails.
- Without a `roles` declaration, `engsys vcs base-branch` gives no answer and reports that fact. If
  it returned an empty value, a hook would use it as a branch name.
- A project without `vcs.branch` is treated as not having adopted the branch conventions and is not
  judged. A project that declares only `vcs.commit` does not fail because of branch checks.
- Hotfix branching diverges only when `prefixes.hotfix` is declared. Without it, hotfix branches
  also branch from the first role branch. Tools do not guess at what was not declared.

## Context and constraints

ADR 0014 moved names to the project but left defaults in the contract. The intent was to keep
existing projects without a declaration from failing on the first day of adoption.

As a result, the standard held `develop` and `feat/`. A project that omitted the declaration
inherited another team's names, and nothing showed that it had. `public-ai-qa` was in that state: it
had not declared `roles` and was running on the standard's defaults.

There was one constraint. Without defaults, tools cannot answer in a project that has no
declaration. However, `engsys init --detect` reads roles from branches that actually exist and
writes them, so new projects are not affected.

## Rationale and alternatives

- **Keep the defaults and have `doctor` warn**: warnings go unread. And until the warning is read,
  that project's hooks and skills run with another team's names.
- **Operate on roles alone, without names**: if `base-branch` returns a role name, a hook cannot
  pass it to `git`. The actual name is needed somewhere, and that place is the project.
- **Have `init` ask when it cannot detect**: `init` must also run non-interactively. When it cannot
  detect anything, it does not create a `vcs` block, and when needed `check-settings` reports what
  to declare.

## Consequences

- A project that declares `vcs.branch.model` must also declare `roles`. `public-ai-qa` declared them
  ahead of this decision.
- Without `prefixes.hotfix`, the base for hotfix branches is the same as for regular work.
  Previously they diverged because of the standard's defaults. A project that needs them to diverge
  declares it.
- Someone reading the standard does not see the name `develop` anywhere. That name exists only in
  each project's contract.
