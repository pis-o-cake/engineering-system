---
type: adr
id: 0002
status: accepted
date: 2026-09-07
---

# 0002. JSON Schema is the source of truth for the contract format; the sh check is an approximation

The source of truth for the project contract format is JSON Schema. `engsys check`, which runs in
projects, must run without dependencies, so it remains an approximate check that looks only at
required fields and top-level keys.

## Context

`schemas/project.schema.json` and `schemas/lock.schema.json` had existed since early v0.1, but no
code read them. The actual check was a `grep` check in `engsys check`, and the contract was written
by `printf` in `write_project_contract`. The source of truth for the format was split across three
places, schema, writer and parser, and a change to any one of them went unnoticed by the other two.

This is the same structure as the problem this system points out in documents: when people
maintain the same fact in several places, the copies eventually diverge.

## Decision

- The **source of truth** for the contract format is **JSON Schema**.
- `engsys check`, which runs in projects, must run without dependencies, so it does not read the
  schema directly. It remains an **approximation** that checks only required fields and the set of
  top-level keys.
- The system repository's tests confirm that the approximation agrees with the source of truth for
  the supported contract cases. `tests/test-schema.sh` validates the contract that bootstrap
  produces against the schema, and confirms that `engsys check` also rejects unknown top-level keys.
  Equivalence over all inputs is not guaranteed.
- Adding a new keyword to the schema requires adding its implementation to
  `tools/lib/jsonschema_min.py`. When the validator meets an unimplemented keyword, it fails
  immediately instead of passing.

## Alternatives

- **Delete the schema**: the duplicate maintenance disappears, but there is no longer a
  machine-readable source of truth for the contract format. Editor support and integration with
  external tools are also given up.
- **Have `engsys check` validate against the schema directly**: there is a single source of truth,
  but projects need a JSON Schema validator. That breaks the boundary in
  [ADR 0001](0001-posix-sh-core-with-python-tooling.md).
- **Have the validator skip unimplemented keywords**: implementation is easier, but the schema
  becomes decoration again. A false signal that the check passed is the worse outcome.

## Consequences

- To change the contract format, change the schema first and update the related tests for the
  writer and the sh check along with it. `sh tests/test-all.sh` checks for mismatches in the cases
  the tests include.
- Violations that the sh approximation misses when a project edits its contract by hand still
  exist. Their scope is detailed format outside the top-level keys and required fields.
