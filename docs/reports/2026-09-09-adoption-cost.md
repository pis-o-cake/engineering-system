---
type: experiment-report
status: active
observed: 2026-09-09
---

# Document check adoption cost and additional detection experiment

In this repeated macOS experiment, the time to run the bundled document checks fell from a median
of 8.95 seconds to 4.14 seconds. The additional delay over the existing native document check fell
from 8.17 seconds to 3.32 seconds, meeting the 5-second criterion set in advance. This result is an
improvement in check execution cost; it does not mean an improvement in people's document writing
time or team productivity.

## Conclusion and applicability

After optimization, all mechanical check conditions of
[evaluation criteria version 1](../verification/adoption.md) were met. Normal input passed in all
5 runs, both injected errors failed, and the checks passed again after restoration. The existing
native check also catches the generated-document mismatch, so that was not counted as an additional
effect of the standard. A body change to a document with an existing review receipt passed native
and failed the standard's review receipt check.

## Method and conditions

The comparison used a temporary clone of the same commit of a product project that is actually
using the standard. Installed dependencies were reused, and each command was run 5 times after one
warmup. The order of native and managed alternated each round. The final comparison ran
sequentially after the other full test runs had finished.

Native was `cd backend && .venv/bin/poe docs:check`. Managed ran the same command plus the
standard's generated-document, structure and review receipt checks. The VCS settings were excluded
from the temporary contract so that only document governance was compared. The pre-comparison
implementation was the existing check-structure.sh; the post-comparison implementation used a
single AWK verdict per document and glob computation inside the shell. The rest of the standard's
implementation was copied from the same working tree.

The raw data records the project commit, the standard's base commit and the hash of the working
diff, the SHA-256 of the files actually executed, and the OS, Python version, and per-run time and
exit code. It contains no code or document bodies from the original project.

## Results

| Metric | Before optimization | After optimization |
|---|---:|---:|
| native median | 0.785 s | 0.788 s |
| managed median | 8.946 s | 4.137 s |
| paired additional delay median | 8.166 s | 3.324 s |
| failures on normal input | 0/5 | 0/5 |
| managed injected-error detection | 2/2 | 2/2 |
| criterion met | fail | pass |

The awk and sed calls that ran repeatedly to read each document's metadata and sections were merged
into a single verdict per document. Path glob computation was also changed from command
substitution to assignment inside the shell. The existing structure checks and the write-time
feedback and scaffold regression checks were kept, confirming the status, required metadata,
references, section order and empty-section verdicts.

The implementation hashes of the two raw data sets differ only in `check-structure.sh`, so the time
difference above comes from that one document verdict implementation. The change that split the
CLI's plugin assembly and cache, and setup, doctor and hook management, into lib modules is present
in both measurements and does not affect these numbers. That split reduced the entry file from
1,815 lines to 1,070 lines, but the total amount of code is similar, and it is not counted as a
productivity saving. Removing the duplicate call to docs:check that the full pytest run in the
applied project was making is also outside this comparison.

Raw data: [before optimization](data/adoption-2026-09-09/before.json),
[after optimization](data/adoption-2026-09-09/after.json).

## Limitations and follow-up

These are results from one project, one computer and 5 runs. Detecting two kinds of injected error
does not guarantee detection of every omission. This experiment did not measure first-install time,
the time people spent finding, writing and reviewing documents, or false-positive recovery and tool
maintenance time. With no comparable records of people's real changes, the team's time-saving rate
is undetermined.

For now, version pinning and the review freshness check are kept. If delay beyond the same criterion
or review cost that grows without additional detections is observed, the scope will be reduced.
Duplicate checks for errors that are already caught are not counted as a separate effect. Server CI
for in-house projects is outside the scope of this experiment because there is no permission for
the central configuration.
