---
type: adr
id: 0016
status: accepted
date: 2026-09-09
---

# 0016. A scaffold fills in the form, not the writing

`engsys docs new` creates a type's metadata, filename and required section headings. It does not
create section content, so a freshly generated file does not pass the structure check. The same
change also fixes a defect: the check did not test whether required sections were empty.

## Decision

- `engsys docs new --type <type> <slug>` creates a document scaffold at the assigned path. If there
  is no assignment, it requires `--path`.
- The type contract gains `heading` and `filename`. `pattern` is a regular expression used for
  checking; `heading` is the string used for generation. A heading cannot be generated from a
  regular expression.
- The type determines the filename. `numbered` adds the next number in that directory, `dated` adds
  today's date, and every other type uses the slug as is.
- Required frontmatter is filled in only where the value is known. `type` and `status` come from the
  contract, date fields get today's date, and the rest are left as `TODO`. No values are invented.
- Sections get headings only. The generation output says so and gives guidance to run
  `engsys docs check` after filling them in.
- `engsys docs check` fails when a required section has empty content. Records with a
  `frozen-status` are also checked for content.

## Context and constraints

Starting a document meant choosing a type, checking the number, writing the frontmatter, and
copying the required section headings over from the contract. All sixteen ADRs in this repository
were created that way.

Removing this work exposed a defect. `engsys docs check` looked only at whether required sections
**existed**, not at whether their content was empty. An empty scaffold passed the check as is.
[design 0002](../design/0002-document-authoring-contracts.md) listed "empty required content" as a
failure condition, but the implementation had left it out.

## Rationale and alternatives

- **Have the scaffold fill in example sentences**: this looks like a faster start, but examples that
  are never deleted stay in the document. The check catches an empty section; nobody catches a
  plausible example sentence.
- **Generate headings from `pattern` without `heading`**: there is no way to pick a heading from
  `결정|채택|Decision`. A regular expression for checking and a string for generation are different
  values.
- **Have a person enter the number**: this was the approach until now. During implementation it
  turned out that the number after `0015` came out as `0014`, because POSIX arithmetic reads a
  leading `0` as octal. This does not mean counting by hand is safer; it means the counting code
  can be wrong.
- **Fill in estimated values instead of `TODO`**: inventing fields such as `criteria` or `target`
  would make the check pass while the content is false. They are left empty for the author to fill
  in.

## Consequences

- There is now one command to start a document. Copying over the type, number, metadata and
  headings goes away.
- A freshly generated file does not pass the structure check. That is intended. The scaffold
  reduces typing; the author writes the text.
- With the new check for required section content, any existing document with an empty section
  fails from this revision on. None of the 19 assigned documents in this repository had one.
- Each type gains `heading` and `filename`. They must be written when a new type is added.
