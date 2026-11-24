---
type: verification-spec
status: active
version: 1
---

# Evaluating the effect and cost of adopting the standard

Whether the checkers work and whether the team saves time are judged separately. The former is
judged by repeatable experiments, the latter by people's working time recorded on real changes.
Passing tests is not interpreted as a productivity gain.

## Scope

This measures the additional error detection and the execution delay of document governance. The
existing project's native document check is the baseline, and the standard's document structure,
review receipt and generated-document checks are added on the same input. VCS settings changes and
overall application test speed are not mixed into this comparison.

The real team effect includes all of document search, editing, review, false-positive recovery and
tool maintenance time. Automated execution time and people's working time are not added together.

## Conditions

- `tools/measure-adoption.py` makes a temporary clone of a clean project. It does not modify the
  original files.
- Installed dependencies are reused. Network installation time and the cost of the first dependency
  installation are not measured.
- Native and managed each get one warmup run and are repeated at least 5 times. The execution order
  alternates each round.
- Record the project revision, the standard's implementation identifier, the OS, the Python
  version, and each run's time and exit code.
- To compare only document checks, the native command in the temporary contract is replaced with
  the given command and the VCS block is excluded.
- Inject a generated-document mismatch and a post-review body change separately, and confirm a
  normal pass after restoring each.
- Public records do not include code, document bodies, credentials or detailed command output.

## Verdict criteria by item

The criteria for the mechanical check experiment are fixed before it runs. It passes with 0
failures on normal input, both injected errors failing under managed, success after restoration,
and a median paired additional delay of 5 seconds or less. If a criterion is exceeded, record the
result as a failure, improve the implementation and measure again under the same conditions. Errors
that native also catches are not counted as additional effect.

The team effect is reviewed after at least 10 real changes are recorded per author and reviewer.
Record the change size and document type with them, and do not compute a time-saving rate when no
comparable pre-adoption records exist. A rule that finds no additional omissions and whose review
and maintenance time keeps growing has its scope reduced or is removed.

Inconsistencies found while the body was unchanged are counted as a separate item. These are cases
where the document hash is unchanged, so the structure check and the review receipt both pass, but
the code, configuration or decision the explanation rests on has changed and the explanation no
longer holds. For each case, record the discovery path (pointed out by a person, change impact
review, periodic check), the number of changes until discovery, and how it was handled. These
numbers are the basis for deciding whether to raise the third verdict into the contract
([docs/design/0003](../design/0003-unresolved-item-ledger.md)).

The required records are: change identifier, document type and size, search/editing/review
minutes, false-positive recovery minutes, tool maintenance minutes, real omissions found by checks,
and whether a baseline exists. Past times that do not exist are not filled in by estimation.

## Evidence and execution

```sh
python3 tools/measure-adoption.py --project /path/to/project \
  --native 'cd backend && .venv/bin/poe docs:check' --samples 5 --output /tmp/adoption.json
```

Raw data and results are kept together in `docs/reports/`. Automated measurement establishes
execution cost and detection of injected errors; verdicts on people's time savings, trust in
documents and overall team quality remain undetermined until real records accumulate.
