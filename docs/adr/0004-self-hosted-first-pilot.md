---
type: adr
id: 0004
status: accepted
date: 2026-09-07
---

# 0004. This repository is the standard's first pilot

This repository itself is the standard's first pilot and directly operates the `.engsys/` contract
and the three-way split of documents. `public-ai-qa` remains the second pilot, one with a language
and a framework.

## Context

The v0.1 design took a separate project (`public-ai-qa`) as the first pilot. Meanwhile this
repository itself had no `.engsys/` contract, no ADRs and no generated documents. The repository
that distributes ADRs and generated documents used neither.

The project where the cost of adopting the standard can be measured first and most cheaply is this
repository. Whatever is inconvenient here is inconvenient in other projects too.

## Decision

- Create the contract in this repository with `engsys init` and commit `.engsys/`.
- Split documents into three responsibilities and actually operate them.
  - `docs/design/` — the judgment at the time (frozen status: `implemented`)
  - `docs/adr/` — the reasons for later changes (frozen status: `accepted`)
  - `docs/architecture/` — the current state
- Facts that can be derived deterministically from declarations, such as the lists of packages,
  skills and hooks, are generated into `docs/generated/system-catalog.md`; a hook blocks direct
  edits and `engsys verify` checks that it is up to date.
- `commands.verify` is `sh tests/test-all.sh`, and the contract check for this repository itself
  also runs inside it.

## Alternatives

- **Use only external pilots**: this has the advantage of validating in a real product, but every
  change to the standard means switching to another repository, and no one notices when the
  standard breaks its own rules.
- **Declare dogfooding only in documentation**: there is no enforcement point, so it is the first
  thing dropped when things get busy.

## Consequences

- When the standard changes, this repository's contract and generated documents break first. The
  adoption cost is paid directly every time.
- `public-ai-qa` remains the second pilot. Problems that surface only in a real project with a
  language and a framework are checked there.
