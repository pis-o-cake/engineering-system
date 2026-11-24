---
type: decision-record
id: 0021
status: accepted
date: 2026-09-10
---

# 0021. A copy without a baseline record is not presumed to be a project edit

When a hook copy differs from the template and `.engsys/hooks.txt` has no baseline record for that
hook, the state is reported as `unrecorded`. It blocks updates exactly as `modified` does; only the
message changes, to say that engsys does not know which side changed.

## Decision

- Add the state `unrecorded`. It has one condition: the copy differs from the current template and
  there is no baseline record for that hook.
- `hooks update` leaves this state as it is and also prints which of `--adopt` and `--force` fits
  which case. `--force` overwrites with the template as before.
- `doctor` reports this state separately as `differs from the template with no baseline`.
- The verdict for copies that do have a baseline record stays as in
  [ADR 0015](0015-hook-copies-are-diagnosed-not-overwritten.md). `current`, `owned`, `outdated`,
  `modified` and `missing` do not change.

## Context and constraints

ADR 0015 grouped copies without a record under `modified`. As a way of blocking updates it was a
safe choice, and the Consequences section of that document already noted that projects that had
already adopted the standard would first appear as `modified`.

The Windows re-verification on 2026-09-10 exposed the cost of that choice. The `commit-msg` copy in
`public-ai-qa` had been reported as `current` up to the previous verification. When the template
changed in b955c49, `engsys hooks status` switched to `modified` and answered
`프로젝트가 고친 사본이다. 갱신하면 그 수정이 사라진다` ("This is a copy the project modified.
Updating will discard that modification."). The project had made no changes to that copy; only the
template had changed. With a record, it would have reported `outdated`.

The same output was reproduced in this repository. Taking a copy planted by `init --hooks`, deleting
only its row from `.engsys/hooks.txt` and making it differ from the template produces `modified`
and `프로젝트가 고친 사본이다` ("This is a copy the project modified."). engsys simply had no way
of knowing that the copy had never been modified, yet the output claimed to know.

The constraint is ownership. A missing record does not make it acceptable to overwrite. The copy may
still be one the project modified, so the default behavior must remain "do not touch it". The only
thing that can change is that engsys stops saying more than it knows.

## Rationale and alternatives

- **Group them under `outdated`**: this makes copies without a record targets for automatic
  updates. Hooks the project modified would be silently reverted, bringing back exactly the
  accident ADR 0015 meant to prevent.
- **Change only the message and keep the state**: the `hooks status` output improves, but `doctor`
  and `setup` decide based on the same `modified` string, so there is no branch point. A state name
  is needed.
- **Record the copy hash on the spot when there is no record**: the diagnosis goes quiet, but a copy
  the project modified gets promoted to "acknowledged". It amounts to writing down that something
  was checked when no person looked at it.

## Consequences

- The five states defined by ADR 0015 become six. Of that document's decisions, only the verdict for
  copies without a record is superseded by this document.
- The message that already-adopted projects see first changes. The remedy is the same as before:
  take the current copy as the baseline with `--adopt`, or take the template with `--force`.
- The `commit-msg` copy in `public-ai-qa` still contains the old fail-open logic. This decision only
  makes that fact reported accurately; whether to apply the update is that project's decision.
