# Engineering System

`.engsys/project.yaml` is this project's standard contract.

- Use the `/engsys:classify-change` skill before a structural change.
- Write commits and merge requests with `/engsys:write-commit` and `/engsys:write-merge-request`. In a session without those skills, read `packages/vcs-gov/commit-contract.yaml` directly.
- Judge the MR body with `engsys vcs check-merge-request`, then open it with `gh pr create --body-file`.
- Link anything this change leaves open to a tracked item with `/engsys:track-unresolved`. `engsys vcs tracker` answers the target and permissions.
- Generated documents and frozen historical records follow their declared lifecycle.
- Treat the native verify command in the project manifest as the source of truth.
- Before writing a new document or restructuring one, settle its type and rules with `/engsys:write-document`.
- Finish document writing and edits with a one-document-at-a-time editorial review via `/engsys:review-document`.
