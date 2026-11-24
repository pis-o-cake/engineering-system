---
type: adr
id: 0014
status: accepted
date: 2026-09-09
---

# 0014. The project names its branches; the model defines only roles

The `vcs-gov` branch model defines only roles and the direction of branching and promotion. The
project declares the actual branch names and prefixes in `vcs.branch`, and hooks, checkers and
skills read that declaration. No tool hardcodes `develop` or `main`.

## Decision

- The model defines its role set with `required-roles` and `extra-roles`. `env-branch` requires
  `development` and `production` and allows further environments between them. `single-main`
  uses only `production`.
- The project declares roles and their branch names in `vcs.branch.roles`. **Declaration order is
  promotion order.** `vcs.branch.prefixes` sets the prefixes for `feature`, `fix` and `hotfix`.
- When nothing is declared, the contract's `branch-defaults` apply, keeping only the roles the
  model requires. Existing projects keep working as before with `develop`, `main`, `feat/`,
  `fix/` and `hotfix/`.
- `engsys vcs base-branch` answers which branch to branch from. A branch that starts with the
  hotfix prefix branches from the last role branch; all others branch from the first role branch.
- `engsys vcs check-settings` checks the declaration, and `engsys verify` calls it. It reports each
  of the following specifically: an unknown model, a missing required role, a role the model does
  not use, a duplicate branch, a role branch missing from `protected`, an MR target that is not a
  role branch, and a prefix that does not end with `/`.
- Name checks run only when `vcs.branch.naming` is declared. A prefix declaration is a value for
  tools to read, not something to enforce.
- `engsys init --detect` reads roles from branches that actually exist. It does not invent
  branches that do not exist.

## Context and constraints

A project could declare only the model and the `protected` list. The actual names were scattered
across individual tools, and the `pre-push` of `public-ai-qa` wrote `origin/develop` and
`origin/main` directly. Renaming a branch meant editing the standard, the project documents and
the hook separately.

The `naming` in `branch-models` was also a fixed string, so a team using different prefixes could
not choose a model.

There is one constraint. This declaration is a local rule. It does not apply the Git server's
protected branch settings; blocking on the server requires configuring those settings separately.

## Rationale and alternatives

- **Declare roles as a mapping**: `development: develop` is easy to read, but it cannot express
  promotion order. With three or more environments the order is itself the policy, so roles are
  declared as a list.
- **Tie prefix declaration to name enforcement**: under this option, declaring prefixes would allow
  only those prefixes. Real repositories also contain branches such as `docs/` and `refactor/`, so
  normal work would be blocked on the first day of adoption. Enforcement happens only when
  `naming` is declared.
- **Require a declaration with no defaults**: every existing project would fail from the start.
  Defaults are kept, but only the roles the model requires remain, so a `single-main` project
  does not fail because of roles it does not use.
- **Have hooks parse the settings directly**: every project would rewrite the same parser. The
  single `base-branch` command provides the answer, and hooks call it.

## Consequences

- Renaming a branch means editing only one place: `roles` and `prefixes`. Hooks and skills that
  use `base-branch` follow along.
- Hooks owned by existing projects do not change automatically. Replacing hardcoded names with a
  call to `engsys vcs base-branch` is that project's task.
- Projects that declare `vcs` also get the settings check in `engsys verify`. An invalid
  declaration is caught before push.
- The server's protected branch settings are still configured by a person. This declaration does
  not replace them.
- The decision to use the contract defaults when nothing is declared was superseded by
  [ADR 0017](0017-the-standard-holds-no-branch-names.md). If the standard holds names, a project
  that omits the declaration inherits another team's names. The rest of this decision stands.
