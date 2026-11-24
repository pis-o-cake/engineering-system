---
type: adr
id: 0008
status: accepted
date: 2026-09-08
---

# 0008. init detects declarations and seeds the project push gate

`engsys init --detect` reads the native verify command, the source of truth, canonical document
paths and lifecycle from the project and fills them in. `--hooks` seeds a `pre-push` gate that the
project will own. It does not create a document scaffold.

## Decision

- `init --detect` fills in **only declarations that have not been set**. Explicit options always
  win. Every value it fills in is printed to the screen.
- When it cannot detect a native verify command, it does not create a default and requires
  `--verify`. If a wrong command were inserted, the first `engsys verify` would fail and the
  standard would look like the cause of that failure.
- Document type assignments are written **only for paths that have no documents yet**. Paths that
  already have documents are not assigned, and those paths are printed. Assigning documents that do
  not declare a type would make every check fail right after adoption.
- `--hooks` copies `templates/project/.githooks/pre-push` into the project and registers it only
  when `core.hooksPath` is empty. Existing hook files and an existing `core.hooksPath` are left unchanged.
- If that gate cannot find `engsys` on PATH, it does not block the push and prints that fact.
- No document scaffold template is created.

## Background and Constraints

`init` took `--verify`, `--source`, `--generated` and `--lifecycle` all by hand. Every new project
meant typing the same values again, and finding out what could be declared required reading `--help`.

Each project's push gate was also written from scratch every time. `public-ai-qa` wrote its own
hook that calls `engsys verify` and the review check for the commits being sent. When every
project recreates the same file, the copies drift apart little by little.

There are two constraints. The standard does not copy shared policy into projects. And the
structure check in [ADR 0006](0006-document-type-contract-in-posix-sh.md) requires assigned
documents to declare a type, so widening assignments automatically would make every check fail on
the first day of adoption.

## Rationale and Alternatives

- **Create a document scaffold template**: this option would prefill `docs/README.md`,
  `docs/architecture/README.md` and an ADR list. But the type contract requires required sections
  to hold the content readers need. A scaffold of empty sections makes the state that contract
  forbids into the default. Documents are created with `write-document` when they are needed.
- **Assign existing documents automatically**: the assignment itself would be accurate. But those
  documents have no type declaration, so `engsys docs check` would fail for all of them at once. A
  failure right after adoption becomes a reason to turn the standard off.
- **Insert `true` when no verify command is detected**: `verify` would always pass, and the gate
  would become decoration.
- **Split profiles by language**: adding `python` and `android` profiles was considered. A profile
  declares a combination of packages, but there are only three packages now and the baseline
  includes all of them. Profiles that differ only in name over the same combination add choices and
  make no difference. Split them when a package that actually differs by language appears.
- **Block the push when the gate cannot find `engsys`**: every push by a team member who has not
  activated would be blocked. A gate that cannot explain why it blocked does not get fixed; it gets
  deleted. Instead, it prints that fact and lets the push through.

## Consequences

- Adoption in a new project is the single line `engsys init --detect --hooks`. The detection
  results are printed and can be checked again in the contract file.
- Detection looks only at the top-level directory. A stack one level down, such as
  `backend/pyproject.toml`, is not found, so pass it directly with `--verify`.
- Projects that already have documents widen assignments by hand. The order is to fix the
  documents to fit their type and then add them to `assign`.
- The `pre-push` a project copied belongs to that project. The standard does not overwrite that
  file later. If the gate needs fixing, fix it in each project.
