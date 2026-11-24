---
type: adr
id: 0006
status: accepted
date: 2026-09-08
---

# 0006. docs-gov owns the document type contract, and the structure check stays POSIX sh

The source of truth for each type's readers, required metadata and required sections is the single
file `packages/docs-gov/document-types.yaml`, and projects only hold declarations that assign types
to paths. The structure check `engsys docs check` is implemented in dependency-free POSIX sh.

## Decision

- The source of truth for the type contract is `packages/docs-gov/document-types.yaml`. Each type
  declares its readers, the question the document answers, required frontmatter, the status
  vocabulary, `frozen-status`, and required sections.
- A project assigns types to paths in `documentation.authoring` of `.engsys/project.yaml`
  (`assign`), and declares paths that are not checked (`exempt`) and paths whose section check is
  deferred (`deferred`). The shared type rules are not copied into the project.
- Required sections are matched with a regular expression `pattern` rather than a fixed heading
  string. Records in a `frozen-status` are checked only for the presence of sections, not their order.
- The structure check is `packages/docs-gov/bin/check-structure.sh` and runs as `engsys docs check`.
  Markdown declares the metadata in frontmatter and HTML declares the same metadata with
  `<meta name="doc-*">`.
- The check covers structure and the existence of evidence paths. Whether the sentences are
  appropriate and the evidence sufficient is judged by the editorial review in
  [ADR 0005](0005-individual-document-editorial-review.md).

## Background

[design 0002](../design/0002-document-authoring-contracts.md) called for a required composition per
type and a structure check for it, but `docs-gov` had only lifecycle classification and editorial
review. Choosing a type was left to the author's memory, and no check prevented missing required
sections.

During implementation two proposals were built at the same time, one checker written in python and
one in sh, so both the contract model and the implementation language had to be chosen.

## Rationale and Alternatives

- **Implement in python**: regex and path handling and YAML reading get shorter. But the check that
  projects run every time would require python3, breaking the boundary by who runs the command that
  [ADR 0001](0001-posix-sh-core-with-python-tooling.md) drew. This standard is planned for Windows
  development servers and Android projects as well, so the prerequisites for adoption are not expanded.
- **Fix required sections to heading strings**: the check and the guidance get simpler, but every
  document written before the contract would have to go on the deferred list. Once deferral becomes
  the default, the check is reduced to a formality.
- **Create a separate skill per type**: authoring guidance becomes friendlier, but the guidance and
  the checker end up with different required compositions. The chosen option is a single
  declaration that both the skill and the checker read.

## Consequences

- Changing a type or its required sections breaks this repository's `engsys docs check` first. This
  keeps the approach of [ADR 0004](0004-self-hosted-first-pilot.md), which pays the adoption cost first.
- The sh parser depends on the declaration depth of `document-types.yaml`. If declarations become
  deeper than they are now, revisit the boundary in ADR 0001.
- The two `docs/design` documents in this repository were written before the contract, so they are
  set to `deferred` and their section check is deferred. Metadata and evidence paths are still
  checked. They are converted when those documents are actually edited.
- Passing the structure check is not a review. A new document is complete only after passing both
  `engsys docs check` and an individual editorial review.
