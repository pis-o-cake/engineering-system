---
type: system-design
status: implemented
scope: engineering-system-v0.1
---

# Foundation v0.1

## Problem

When good policies are copied into each project, their updates, application and verification
drift apart. When long Markdown is always loaded into context, the LLM misses the key instructions.

## Draft decisions

| Question | v0.1 default |
|---|---|
| Distribution unit | A single `engsys` plugin at the repo root, split internally into packages and profiles |
| Activation | Once per developer machine. No per-project dependency or plugin install |
| Project contract | `.engsys/project.yaml` + `.engsys/lock.yaml` |
| Policy source of truth | `policy.yaml`, schemas, check code |
| Markdown | Holds only routes, short decision records and templates |
| Enforcement | Claude hooks assist the agent. Native tests, Git hooks and CI are the hard gate |
| Update | An upgrade workflow that explicitly raises the project lock |

## Project contract lifecycle

`project.yaml` holds the sources of truth and native commands that the project declares. It records
no version. `lock.yaml` pins the package revisions that the profile actually resolved. Bootstrap
creates both; upgrade first shows a plan and then changes only the lock and the generated adapters.

## Component boundaries

| Component | Responsibility | Copied into the project? |
|---|---|---|
| `foundation` | contract, profile, bootstrap, upgrade, compatibility | No |
| `docs-gov` | lifecycle, impact prompts, generated and historical guardrails | No |
| `pipeline` | order of contract checks and project-native verification | No |
| profile | package combination and choice of language/framework adapters | Declaration only |
| project manifest | sources of truth and native commands | Yes |
| lock | applied versions | Yes |

The source of truth for Claude Code skills and hook handlers lives under each package's
`claude-code/` directory. The root manifest exists for catalog validation, and the launcher assembles
only the packages listed in the lock into a local cache plugin view.

## Execution flow

```text
New project     → bootstrap(profile) → manifest + lock + short Claude route
Change request  → classify skill → prompt or native hard gate
System update   → upgrade plan → project lock change → verification
```

## Role of Claude Code

- Skills read the current project manifest and diff and ask only the questions needed for a decision.
- Skills that write, such as scaffold, are invoked explicitly by the user.
- Hooks block only prohibitions that need no judgment, such as editing generated output directly.
- In v0.1, edits to the body of a historical record are not blocked; the lifecycle skill and native
  checks review them.
- For human and CI paths that hooks do not reach, the project's native gate checks the same rules.

## Developer activation and the lock

A developer registers the output of `engsys shellenv` from the cloned system root in their shell
profile once. In a project, they start Claude Code with `engsys claude`. This launcher selects the
clean system worktree and local cache plugin view that match the revision and package set in
`.engsys/lock.yaml`.

As a result, pulling the system catalog does not by itself change the skills or hooks of an older
project. The only way to change the lock is the `engsys upgrade` plan followed by an explicit `--apply`.

## Context budget

The project route stays at 12 lines or fewer. Skill descriptions stay at 240 characters or fewer and
skill bodies at 150 lines or fewer. Skills read detailed references only when needed. A
`UserPromptSubmit` classifier and automatic `Stop` verification add context and friction to every
turn, so v0.1 does not use them.

## Guardrail matrix

| Target | Skill | Claude hook | Native gate |
|---|---|---|---|
| generated output | points to the generator and the source of truth | blocks direct edits | compares against generator output |
| historical record | explains the lifecycle and allowed scope | none | metadata and link checks |
| runtime, DB and API changes | asks documentation impact questions | none | the project's tests and schema checks |

## Non-goal

- v0.1 does not support every framework and CI.
- The LLM does not decide whether an ADR is needed or what a document says.
- System updates are not applied to existing projects automatically.

## Pilot success

- A new fixture project creates the baseline contract without adding dependencies.
- `public-ai-qa` connects its documentation policy through the manifest and lock alone.
- A skill's default context contains only its description and the project route.
- The responsibilities of the hard gate and the LLM hooks do not overlap.

## Next design work

1. The exact lifecycle of the manifest and the lock
2. Bootstrap and upgrade inputs and outputs
3. The docs-gov matrix of triggers, prompts and hard gates
4. The skill and hook contract of the Claude plugin
