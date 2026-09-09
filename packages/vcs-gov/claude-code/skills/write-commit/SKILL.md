---
name: write-commit
description: Write a commit message against this project's declared commit contract. Use before creating any commit in a project whose contract declares a vcs block.
---

# Write a commit message

Read `packages/vcs-gov/commit-contract.yaml` under the plugin root for the format, the type
vocabulary, the subject limit, and the forbidden trailers. Read `vcs.commit` in the project's
`.engsys/project.yaml` for the values this project chose — subject language, subject ending, and
the scope vocabulary. Do not copy either into the project.

Decide the scope of the commit before the wording. One commit carries one purpose. A subject that
needs a list to describe the change is the signal to split the commit, not to shorten the list.
The native check warns about that and still lets it through; splitting is your judgement.

Write the header as the contract's format. Use a declared type and, when the project declares a
scope vocabulary, a declared scope. Adding a scope means adding it to the project declaration in
the same commit, not writing it once and moving on.

The subject states what changed. Not "업데이트", not "수정함", not the file names. Use the name that
actually appears in the code or on the screen so the commit is findable later. Follow the declared
subject ending; the contract's guidance for that ending says what it requires.

The body explains what and why. The code already shows how. Omit the body when the change carries
its own explanation. Keep the declared wrap width. Breaking changes take `!` after the type and a
`BREAKING CHANGE:` footer.

When the work needs a new branch, ask the project which branch it is cut from rather than
assuming `develop` or `main`:

```sh
"$ENGSYS_PLUGIN_ROOT/bin/engsys" vcs base-branch --project <project> --branch <new-branch>
```

The answer follows the project's declared roles and prefixes: a hotfix branch is cut from the last
role branch, everything else from the first.

Verify before committing, from the project root:

```sh
"$ENGSYS_PLUGIN_ROOT/bin/engsys" vcs check-message <message-file> --project <project>
```

The project's `commit-msg` hook runs the same check, so a passing message is not a passing commit —
the hook only judges what a machine can judge. Whether the commit holds one purpose, and whether
the body answers why, stays with you.
