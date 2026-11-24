---
type: guide
status: active
---

# Engineering System

**English** | [한국어](README.ko.md)

An executable standard that makes the same engineering judgments repeatable across projects.

## Boundaries

- This repository is the source of truth for packages, profiles, the Claude Code plugin, schemas,
  and fixtures.
- A project declares the standard and version it uses in `.engsys/project.yaml` and
  `.engsys/lock.yaml`.
- Shared policies, skills, and hooks are not copied into projects.
- Each package owns its Claude Code skills and hook handlers. The launcher assembles only the
  packages in the lock into a local cache plugin view.
- Deterministic rules are checked by the project's native tests, Git hooks, and CI.

## v0.1

The current packages are `foundation`, `docs-gov`, `vcs-gov`, and `pipeline`. This repository is
its own first pilot and adopts its own standard through `.engsys/`.

- [Current architecture](docs/architecture/README.md) — how things are now
- [Architecture Decision Records](docs/adr) — why things changed since then
- [Foundation design](docs/design/0001-foundation.md) — why it was designed this way at the time
- [System catalog](docs/generated/system-catalog.md) — packages and skills generated from declarations
- [Project contract schema](schemas/project.schema.json)
- [Project lock schema](schemas/lock.schema.json)
- [Baseline profile](profiles/baseline.yaml)
- [Bootstrap workflow](workflows/bootstrap.yaml)
- [Adoption evaluation](docs/verification/adoption.md) — criteria for judging effect and running cost

## Getting started

Clone the standard once. For each project you attach it to, declare the standard and version to
use in two contract files. The `setup` command below walks you through creating the contract and
wiring the project's Git hooks.

### 1. Clone and activate the standard — once per machine

```sh
git clone https://github.com/pis-o-cake/engineering-system
cd engineering-system
./install.sh
```

`install.sh` changes two things. It adds one line to your shell profile (`~/.zshrc` and the like)
that puts `engsys` on PATH, and it sets the Git hook path of this clone. It does not touch other
projects. To undo it, delete that line.

When it finishes, **open a new terminal** so that `engsys` is picked up.

### 2. Run setup in the target project — once per project

```sh
cd /my/project
engsys setup
```

No path argument is needed. The current directory is the target.

`setup` runs eight steps in order.

| Step | What it does |
|---|---|
| 1. Prerequisites | Checks that `git` exists. `python3` and Claude Code are optional; if missing, it tells you what will not work |
| 2. System checkout | Checks which revision the standard is at and whether teammates can fetch it |
| 3. Developer activation | Checks that `engsys` is on PATH. If not, asks whether to run `install.sh` |
| 4. Target project | Scans the project to **detect check commands, source paths, and branch names, shows the full contract it will create first**, then asks whether to create it |
| 5. Git hooks | Asks whether to install `commit-msg` and `pre-push`, and whether to set `core.hooksPath` if it is unset. Existing hooks you have modified are not overwritten |
| 6. Checks | Validates the contract and asks whether to run the project's existing tests too |
| 7. Final diagnosis | Runs `doctor` once more. Does not report success while problems remain |
| 8. What is left | Lists what is not yet declared and which files to commit |

**It always shows a change and asks before modifying a file.** Pass `--yes` to proceed without
prompts. Without a terminal and without `--yes`, it does not start — proceeding when it cannot ask
would end as an apparent success that did nothing.

### 3. Commit the generated files

```sh
git add .engsys .githooks .claude
git commit -m "build(engsys): Engineering System 계약 추가"
```

Teammates receive the same contract only when these files are committed.

### What teammates do

Because `.claude/settings.json` declares the standard as a marketplace, skills and document
guardrails **attach automatically** when a teammate opens the project in Claude Code — the CLI,
the desktop app, or an IDE extension alike. They do not need to know about `engsys claude`
([ADR 0023](docs/adr/0023-the-standard-ships-as-a-plugin-marketplace.md)).

**The plugin does not carry the code that judges, though.** What attaches is the skills and the
hook wiring, and those hooks call `engsys` on PATH. Without `engsys`, the plugin is attached but
judges nothing. `engsys doctor` reports this state as a failure.

So each teammate still does the remaining two steps once.

```sh
git clone https://github.com/pis-o-cake/engineering-system && cd engineering-system && ./install.sh
cd /my/project && engsys setup
```

- **`install.sh`** — the plugin does not carry the judging code (`engsys`). It must exist on each
  machine.
- **`engsys setup`** — sets `core.hooksPath`. That setting lives in `.git/config` and is **not
  committed**, so a clone alone does not carry it. Without it, Git does not call the hook files
  even though they exist.

If both are skipped, `pre-push` reports the cause and blocks the push.

### When setup fails

`setup` does not roll anything back on failure. At the end it repeats the step where it stopped
and what to do next, and it saves the full output to a file that survives a closed terminal. The
CLI prints these messages in Korean:

```
멈춘 곳: [4] 대상 프로젝트
위의 마지막 오류 줄이 이유다. 아무것도 되돌리지 않았으니 고치고 다시 실행하면 된다.

  지금 상태 보기 : engsys doctor --project /내/프로젝트
  다시 실행      : engsys setup --project /내/프로젝트
  전체 기록      : /tmp/engsys-setup-4471.log
```

After fixing the cause, run `engsys setup` again. Steps already completed pass through unchanged.

### Checking status

```sh
engsys doctor      # what is missing now, and which command fixes each item
engsys verify      # runs contract, document, and project tests
```

`doctor` only diagnoses and changes nothing. It tells you what to run; you run it yourself.

### Windows

`engsys` runs only in Git Bash. `bin/engsys` is an extensionless POSIX sh script that PowerShell
and CMD cannot execute, and `install.sh` edits only the bash login profile, so neither shell gets
anything on its PATH. Even after activation, PowerShell answers like this:

```
The term 'engsys' is not recognized as the name of a cmdlet, function, script file, ...
```

This does not mean installation failed; it means the wrong shell is open. Open Git Bash and run
the command again.

If `engsys` is not on PATH yet because activation has not run, call it through `sh`.

```sh
cd /d/dev/engineering-system && sh install.sh
```

Write paths as `/d/work/myapp`, not `D:\work\myapp`.

This repository pins line endings to LF through `.gitattributes`. If Git for Windows' default
(`core.autocrlf=true`) checks files out with CRLF, the sh parser reads the trailing CR as part of
a value and fails with misleading errors such as `invalid profile name: 'baseline'`. If an
existing checkout hits this, open the file the error points to in an editor, change its line
endings to **LF**, and save. Keep the content, convert only the line endings, and check again.
There is no need to reset the whole repository.

---

The sections below describe, one by one, the commands that `setup` calls. If you know them, you
can use them directly.

## Activation

A teammate runs this once after cloning this repository. It changes only the developer's own shell
profile and this clone's Git hook path, and writes nothing to projects.

```sh
git clone https://github.com/pis-o-cake/engineering-system
cd engineering-system && ./install.sh     # Windows: sh install.sh (Git Bash)
```

`--print` prints only the line to add to the profile. If the profile already has a line pointing
at a different checkout, it is not overwritten; the command reports that line instead.

Check activation at any time with `engsys doctor`. It reports the PATH link, whether this clone
can fetch the locked revision, whether the contract passes `engsys check`, and whether
origin/main has a newer revision, with the command to run for each.

```sh
engsys doctor --project /path/to/project
```

## Upgrading the standard

The release channel is `origin/main`. The lock records the revision of the system checkout of the
developer who ran the command, so put the checkout at the point you want before upgrading. To pin
a specific release, check out its tag.

```sh
git -C /path/to/engineering-system checkout main && git -C /path/to/engineering-system pull
engsys upgrade --project /path/to/project            # prints the plan only
engsys upgrade --project /path/to/project --apply
```

Commands that check a project (`check`, `sync`, `verify`, `docs`, `review`, `vcs`) **run at the
revision the project locked.** The `engsys` on PATH is a runner; the judging code comes from the
release the lock points to. Even if a checkout at the same revision has uncommitted changes, the
command runs from a clean cache. If the locked revision cannot be prepared or the cache has been
modified, the command fails instead of falling back to the current checkout. `init`, `upgrade`,
and `doctor` are not redirected. Checks of this repository itself use the current code; to try a
change to the standard in another project, set `ENGSYS_USE_CHECKOUT=1` explicitly
([ADR 0019](docs/adr/0019-verification-fails-when-it-cannot-run.md)).

`engsys verify --revision <commit>` first checks that the working tree matches that commit; if not,
it prints what differs and stops. The default `pre-push` calls it this way, so the gate passes only
when what was checked equals what is sent. To push a ref with different content, check out that
commit and run it again. The push also stops when the check cannot start because `engsys` is not
on PATH ([ADR 0019](docs/adr/0019-verification-fails-when-it-cannot-run.md)).

`--apply` runs the native tests and generated document checks with the new lock and restores the
previous lock on failure. `doctor` warns when the lock is not yet on `origin/main`. Pushing the
project in that state leaves teammates' clones unable to fetch that revision.

## Adopting a project

In the target Git project, only the adapter is created, with no dependency installation. `init`
never overwrites an existing contract. After editing the manifest by hand, run `sync` and then
`check`.

```sh
engsys init --project /path/to/project --detect --hooks
engsys verify --project /path/to/project
```

`--dry-run` shows what would be written and changes nothing.

`--detect` fills only the unset declarations from the project and prints every value it filled —
the native verify command, source-of-truth directories, the canonical documentation paths,
lifecycle, and type assignments for paths that have no documents yet. Paths that already contain
documents are not assigned; the command lists them instead, because assigning documents with no
declared type would fail every check on the first day of adoption. Explicit options always take
precedence over detection.

Detection looks only at top-level directories. It does not find a stack one level down, such as
`backend/pyproject.toml`, so pass it directly, e.g. `--verify 'cd backend && poe check'`.

Copied hooks belong to the project, so the standard does not overwrite them. `engsys hooks status`
reports when the template has changed.

```sh
engsys hooks status --project /path/to/project
engsys hooks update --project /path/to/project           # updates only unmodified copies
engsys hooks update --project /path/to/project --adopt   # keeps the copy and records the check only
```

A modified copy does not change without `--force`. The record lives in `.engsys/hooks.txt`, which
the project commits ([ADR 0015](docs/adr/0015-hook-copies-are-diagnosed-not-overwritten.md)).

`--hooks` copies the `pre-push` gate into the project and registers it only when `core.hooksPath`
is empty. The project owns that file, and the standard does not overwrite it later
([ADR 0008](docs/adr/0008-init-detects-declarations-and-seeds-the-project-gate.md)).

### What `engsys check` sees and does not see

`check` must run without dependencies, so it reads the contract with sed and awk. The supported
syntax is two-space-indented mappings and sequences, single-quoted scalars, and inline lists of
the form `[a, b]`. Any other syntax is not read.

It checks the set of top-level keys, the presence of required entries, and **whether each declared
block was actually read**. If `documentation.authoring`, `documentation.review`,
`documentation.lifecycle`, or `vcs.branch` is declared but no entry is read, it ends with an error.
This closes the path where a badly indented contract silently passed with zero entries.

It does not check value formats or the full nested structure. The source of truth for the contract
format is the [project schema](schemas/project.schema.json), and the full validation runs in this
system repository's tests ([ADR 0002](docs/adr/0002-contract-schema-is-canonical.md)).

`check` quickly validates only the adapter and the lock. `verify` then runs the native tests and
generated document checks the project declares. Changing a profile or adding a package does not
change an existing lock — applying it is the job of `upgrade` in "Upgrading the standard" above.

### When commands differ by OS

`npm test`, `go test ./...`, `cargo test`, and `./gradlew check` are the same string on every OS,
so one line is enough. Declare variants only when the execution path differs, as with a Python
venv.

```yaml
commands:
  verify: 'cd backend && .venv/bin/poe check'          # macOS and Linux
  verify-windows: 'cd backend && .venv/Scripts/poe check'
```

`engsys verify` decides with `uname` and picks the right one. The command typed on either machine
is the same, and the chosen key is printed —
`Running project verification (commands.verify-windows): ...`. The only suffixes are `-macos`,
`-linux`, and `-windows`, and the unsuffixed default declaration remains required.
`documentation.generated[].command` has `command-windows` in the same way.

`documentation.generated` is read regardless of the order of `output` and `command`. Each entry must
be a block mapping with both values. Unsupported inline mappings and multiline scalars are treated
as errors. If a command needs quotes or escapes, use a single-quoted scalar.

### Attaching to Claude Code

There are two ways to attach the standard to Claude Code. The default is for the project's
`.claude/settings.json` to declare the standard as a marketplace; that file is committed, so the
standard attaches the same way however the session is opened. In this path, the skills and hook
wiring come from the standard's `main`.

`engsys claude` is **reproduction mode**. Use it to revisit a project bound to an old lock with
the guidance of that time, or to work on the standard itself. It is not the default path for daily
work. The launcher selects a clean system worktree at the lock revision, then assembles only the
packages in the lock into a developer-local cache plugin view. Skills and hooks that were not
selected are therefore not registered with Claude.

Either way, **the verdict is pinned.** The hooks call `engsys`, and `engsys` re-executes itself at
the lock revision. What can drift in the marketplace path is the guidance text, not the pass/fail
result ([ADR 0023](docs/adr/0023-the-standard-ships-as-a-plugin-marketplace.md)).

The launcher exports the plugin view path as `ENGSYS_PLUGIN_ROOT`. Skills run scripts inside the
plugin only through this variable. `CLAUDE_PLUGIN_ROOT` is exclusive to hook processes and is
empty inside skills ([ADR 0003](docs/adr/0003-skill-uses-launcher-environment.md)).

## Developing the system repository

One prerequisite applies only when changing this repository: the check and generation tools in
`tools/` use the python3 standard library. Projects that adopt the standard do not have this
prerequisite ([ADR 0001](docs/adr/0001-posix-sh-core-with-python-tooling.md)).

```sh
sh tests/test-all.sh          # full check (this repository's commands.verify)
bin/engsys verify --project . # contract check + the tests above + generated document freshness
```

There is no server-side CI yet. `.githooks/pre-push` enforces checks before push. For every ref
sent except deletions, it runs `bin/engsys verify --project . --revision <commit>`, so it passes
only when what was checked equals what is sent. `install.sh` registers it, and `engsys doctor`
reports whether it is registered.

A person can bypass local hooks. Until a server-side check exists, a pass is a result obtained in
the pushing developer's environment and does not guarantee behavior on other OSes.

The native checks include a self-lock freshness check. After a commit that changes `packages/`,
`bin/`, or `lib/`, raise this repository's own lock with `bin/engsys upgrade --project . --apply`
and commit the lock change. Otherwise `engsys claude` assembles the skills and hooks of the
pre-merge revision.

Nobody edits `docs/generated/` by hand. Regenerate it with `python3 tools/generate-catalog.py`.

This repository's native checks also include `python3 tools/check-documentation.py`. It checks the
required frontmatter of the historical documents declared in `.engsys/`, the policy's status list,
and that local link targets exist. It does not compare prose with current code or check external
URLs or heading fragments. Document checks for other projects belong to those projects' native
commands.

## Commit and merge request conventions

The source of truth for the commit header format, the type list, subject length, forbidden
trailers, and the required sections of an MR body is the
[commit contract](packages/vcs-gov/commit-contract.yaml). A project declares only values in the
`vcs` block of `.engsys/project.yaml` — the subject language and ending, the `scope` list, the
branch model, and the MR target branch.

```sh
engsys vcs check-message .git/COMMIT_EDITMSG --project .
```

The `commit-msg` hook that `engsys init --hooks` installs runs the same check. Commits are also
made outside sessions, so enforcement belongs to the native Git hook, not to a Claude Code hook.
`/engsys:write-commit` and `/engsys:write-merge-request` help with writing.

An MR body is not inside Git, so there is no point to attach a Git hook to. Instead, the body is
written to a file and judged.

```sh
engsys vcs check-merge-request pr-body.md --title 'fix(auth): 로그인 게이트 추가' --project .
gh pr create --title 'fix(auth): 로그인 게이트 추가' --body-file pr-body.md
```

The hook the plugin registers calls the same check before `gh pr create`. An unreadable inline
`--body` is blocked. **What enforces this is the declaration stored in the repository, not a skill
the session happened to read** — the `.claude/settings.json` that `init` leaves attaches the plugin,
and that plugin carries the gate
([ADR 0022](docs/adr/0022-a-declared-contract-needs-a-gate-not-an-instruction.md) ·
[ADR 0025](docs/adr/0025-the-gate-travels-with-the-plugin-not-the-path.md)).
The hook looks for `engsys` in the order `ENGSYS_SYSTEM_ROOT` → `CLAUDE_PLUGIN_ROOT` → PATH. It
sometimes runs outside a login shell, so relying on PATH alone would leave the gate silently off.

The check covers section headings and their order, headings outside the declaration, empty
sections, forbidden phrases, and the title format. Style and repetition are left to reviewers.

### Branch model

The branch model defines only roles and the direction of branching and promotion. The project
chooses the actual names.

```yaml
vcs:
  branch:
    model: 'env-branch'
    roles:                    # declaration order is promotion order
      - role: 'development'
        branch: 'develop'
      - role: 'production'
        branch: 'main'
    prefixes:
      feature: 'feat/'
      hotfix: 'hotfix/'
```

**The standard holds no branch names.** Without a declaration, `engsys vcs check-settings` reports
what to declare, and `base-branch` gives no answer. Hotfix branching splits off only when
`prefixes.hotfix` is declared ([ADR 0017](docs/adr/0017-the-standard-holds-no-branch-names.md)).

`engsys vcs base-branch` answers the base to branch from, and `engsys vcs settings` shows the
resolved values. Hooks and skills use these commands instead of writing branch names directly.
`check-settings` in `engsys verify` catches invalid declarations.

This declaration is a local rule. **It does not apply the Git server's protected branch settings.**

Branch naming rules default to the model's `naming`; a pattern the project declares in
`vcs.branch.naming` wins. `engsys vcs check-branch` judges names only when one is declared, and the
push gate calls it. Protected branches and detached HEAD are out of scope.

Only what a machine can judge is blocked. Signals that a commit should be split, such as a `·`
enumeration, are left as warnings and pass
([ADR 0011](docs/adr/0011-vcs-gov-owns-the-commit-and-merge-request-contract.md)).

## What this change leaves open

Anything this change does not close is linked to a tracked item that has an owner and a closing
condition. Documents do not track that state again. The standard holds the
[tracker contract](packages/vcs-gov/tracker-contract.yaml) — item kinds and the nature of their
closing conditions, required information, duplicate checks, when to register, and closing
evidence — and the project declares which tool and which labels to use.

```yaml
vcs:
  tracker:
    provider: 'gitlab'              # github or gitlab
    project: 'group/thing'
    default-assignee: 'someone'
    labels:
      defect: '결함'
    agent:                          # allowed or ask
      create: 'allowed'
      close: 'ask'
```

**The standard holds no tracker names and no label names.** Without a declaration,
`engsys vcs tracker` gives no answer. `engsys vcs check-tracker` judges the declaration, and
`accept-risk` and `commit-deadline` cannot be opened to `allowed` because the contract pins them to
a human ([ADR 0024](docs/adr/0024-the-project-declares-its-tracker-and-agent-permissions.md)).

If the MR body's `영향 및 후속 작업` (impact and follow-up) section contains wording that implies
follow-up work but has no tracked item link, the gate blocks it. It checks only the link format,
not the item's content. When nothing remains, write `없음` (none). `/engsys:track-unresolved`
handles registration, duplicate checks, and evidence updates in one flow.

## Document types and structure checks

A new document starts by choosing its type. The source of truth for each type's readers, the
question it answers, required metadata, and required sections is
[document types](packages/docs-gov/document-types.yaml), and the project assigns types to paths in
`documentation.authoring` of `.engsys/project.yaml`. `/engsys:write-document` provides the
procedure for reading that contract before writing.

```sh
engsys docs new --type decision-record --project . cache-strategy
engsys docs check --project .
```

`docs new` creates the metadata and required section headings at the assigned path, and adds the
number or date in the format the type defines. **It does not write section content, so a freshly
created file does not pass the check** — the scaffold saves typing, and the author writes the text
([ADR 0016](docs/adr/0016-a-scaffold-fills-the-form-not-the-writing.md)).

`--path <document>` checks that one document only. Unassigned paths and missing files are not
errors.

In a session where the standard is attached as a plugin, this check runs automatically. Right
after a document is written, that one document is checked, and a failure is passed back to Claude
to fix on the spot. When a session opens, the number of documents without a review receipt is
injected as one line. Documents a person edits directly in an editor are not caught by this layer;
the push gate catches them ([ADR 0009](docs/adr/0009-document-structure-feedback-at-write-time.md)).

Besides the number of assigned documents and the findings, the output shows the size of **deferred
section checks, exclusions, and unassigned documents**. If only pass/fail were shown, there would
be no way to see what is outside the check. For unassigned documents, up to five paths are printed.

For assigned documents, it checks the type, status, required metadata, evidence paths, the leading
paragraph, and required sections. Records whose status is in the type's `frozen-status` are checked
only for the presence of sections, not their order, and paths declared `deferred` skip section
checks and get metadata checks only. The structure check does not judge style
([ADR 0006](docs/adr/0006-document-type-contract-in-posix-sh.md)).

## Editorial review of documents

Reports, operations documents, and design documents are read and revised one at a time against
the [editorial criteria](packages/docs-gov/editorial.md). `/engsys:review-document` provides the
procedure for reviewing the final text and leaving a per-document receipt. The receipt holds the
content hash, the reviewer, the readers, the question the document answers, and concrete review
observations.

```sh
engsys review status
engsys review record --document docs/report.md --blob <reviewed-content-hash> \
  --reviewer <actual-reviewer> --audience <readers> --purpose <question-answered> --notes-file <review-notes>
engsys review check
```

The source of truth for the check scope is `documentation.review.scopes` in the contract. Without
`--scope`, the command reads that list, so project hooks do not parse it again. A project wires
`engsys review check` into its native checks. Generated documents are excluded; new documents and
documents changed after review fail. Adding an existing document to the scope also requires an
initial individual review. Commit each document together with its receipt in `.engsys/reviews/`.
Style is never judged automatically, and documents are never approved in bulk.

In the push gate, `engsys review check --revision <commit-to-send>` checks the content to be sent
together with its receipts. The scope and the list of generated documents are also read from that
commit's contract. This repository wires it into `.githooks/pre-push`. The check confirms that
review receipts exist and are fresh; it does not prove the quality of the writing or a manager's
approval.
