---
type: adr
id: 0001
status: accepted
date: 2026-09-07
---

# 0001. The engsys core stays POSIX sh; only development tools use python3

The engsys core stays dependency-free POSIX sh, and tools that use python3 are limited to
development of the system repository. Projects that adopt the standard are not required to have python3.

## Context

`bin/engsys` is about 850 lines of POSIX sh and reads YAML with `sed` and `awk`. This parser can
only interpret the formats engsys itself writes, so it reaches its limit as nested contracts grow.
On the other hand, not installing dependencies into a project is a core promise of v0.1, because
the cost of adopting the standard is exactly what makes the standard fail.

The two requirements collide on the question "who runs it". Commands that project developers and
CI run every time and commands that only people changing the system repository run have no reason
to share the same constraints.

## Decision

Draw the boundary by who runs the command.

- `bin/engsys` stays dependency-free POSIX sh. Projects and CI run only this.
- `tools/*` is for developing the system repository and uses the python3 standard library. Projects do not run it.
- python3 is therefore a prerequisite for contributing to this repository, not for projects that adopt the standard.

## Alternatives

- **Keep everything in sh**: schema validation and catalog generation would have to be written in
  awk. That is hard to read, and if the validator is silently wrong, the check itself is meaningless.
- **Rewrite the core in python or Go**: parsing gets easier, but projects take on a runtime or a
  binary distribution. That breaks the "zero adoption cost" hypothesis v0.1 sets out to test.

## Consequences

- The limits of the sh parser remain. Revisit this decision when contracts nest three or more
  levels deep or when projects start editing contracts heavily by hand.
- So that those limits are not crossed silently, the contract format is caught in tests by the
  schema check in [ADR 0002](0002-contract-schema-is-canonical.md).
- Running the system repository's tests requires python3. The README states it as a prerequisite.
