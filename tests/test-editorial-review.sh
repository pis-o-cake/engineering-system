#!/bin/sh

set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' 0
project="$temporary/project"
mkdir -p "$project/docs"
git -C "$project" init -q
git -C "$project" config user.name 'Review Fixture'
git -C "$project" config user.email 'fixture@example.test'
"$system_root/bin/engsys" init --project "$project" --verify true \
  --generated docs/generated.md true >/dev/null
printf '# Report\n\nThe release needs a schedule decision.\n' >"$project/docs/report with space.md"
printf '# Generated\n' >"$project/docs/generated.md"
printf 'The conclusion names the schedule decision; no unsupported performance claims remain.\n' >"$temporary/notes"

review() { "$system_root/bin/engsys" review "$@" --project "$project"; }
reject() {
  if review "$@" >"$temporary/result" 2>&1; then
    printf 'Unexpected review success: %s\n' "$*" >&2
    exit 1
  fi
}

# Missing reviews fail even for newly created, untracked documents.
reject check --scope docs
grep -Fq 'docs/report with space.md' "$temporary/result"
if grep -Fq 'docs/generated.md' "$temporary/result"; then exit 1; fi
review status --scope docs >/dev/null
blob=$(git -C "$project" hash-object --no-filters -- 'docs/report with space.md')
reject record --document 'docs/report with space.md' --blob old-content \
  --reviewer fixture --audience managers --purpose 'Decide the schedule' --notes-file "$temporary/notes"
reject record --document 'docs/report with space.md' --document docs/another.md
reject record --document docs/generated.md --blob "$blob" \
  --reviewer fixture --audience managers --purpose 'Decide the schedule' --notes-file "$temporary/notes"
: >"$temporary/empty-notes"
reject record --document 'docs/report with space.md' --blob "$blob" \
  --reviewer fixture --audience managers --purpose 'Decide the schedule' --notes-file "$temporary/empty-notes"

review record --document 'docs/report with space.md' --blob "$blob" \
  --reviewer fixture --audience managers --purpose 'Decide the schedule' --notes-file "$temporary/notes" >/dev/null
review check --scope docs >/dev/null

# The same receipt cannot approve another document or a changed body.
cp "$project/docs/report with space.md" "$project/docs/copied.md"
cp "$project/.engsys/reviews/docs/report with space.md.review" "$project/.engsys/reviews/docs/copied.md.review"
reject check --scope docs
grep -Fq 'docs/copied.md' "$temporary/result"
rm "$project/docs/copied.md" "$project/.engsys/reviews/docs/copied.md.review"
printf '\nAn unreviewed paragraph.\n' >>"$project/docs/report with space.md"
reject check --scope docs
reject record --document 'docs/report with space.md' --blob "$blob" \
  --reviewer fixture --audience managers --purpose 'Decide the schedule' --notes-file "$temporary/notes"

# A push gate must check committed documents and receipts, not a later working-tree review.
git -C "$project" add -A
git -C "$project" commit -qm 'fixture: stale committed review'
stale_revision=$(git -C "$project" rev-parse HEAD)
blob=$(git -C "$project" hash-object --no-filters -- 'docs/report with space.md')
review record --document 'docs/report with space.md' --blob "$blob" \
  --reviewer fixture --audience managers --purpose 'Decide the schedule' --notes-file "$temporary/notes" >/dev/null
review check --scope docs >/dev/null
reject check --scope docs --revision "$stale_revision"
git -C "$project" add -A
git -C "$project" commit -qm 'fixture: reviewed committed document'
review check --scope docs --revision HEAD >/dev/null
printf '\nWorking tree change.\n' >>"$project/docs/report with space.md"
review check --scope docs --revision HEAD >/dev/null
reject check --scope docs

# HTML reports follow the same rule; missing scopes and malformed receipts fail closed.
printf '<h1>Report</h1>\n' >"$project/docs/brief.html"
reject check --scope docs/brief.html
reject check
reject check --scope missing
reject check --scope docs --scope missing
printf '\ndecision: fail\n' >"$project/.engsys/reviews/docs/report with space.md.review"
reject check --scope 'docs/report with space.md'

# --scope 없이 부르면 계약의 documentation.review.scopes 를 정본으로 쓴다.
reject check
grep -Fq 'pass --scope or declare documentation.review.scopes' "$temporary/result"
cat >>"$project/.engsys/project.yaml" <<'EOF'
  review:
    scopes:
      - 'docs'
EOF
reject check
grep -Fq 'docs/brief.html' "$temporary/result"
python3 "$system_root/tools/validate-contract.py" project "$project/.engsys/project.yaml" >/dev/null

# Hook input must survive native tests that read stdin, and deleted refs are skipped.
mkdir -p "$project/bin" "$project/tests"
printf '#!/bin/sh\ncat >/dev/null\n' >"$project/tests/test-all.sh"
cat >"$project/bin/engsys" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>hook-calls
SH
chmod +x "$project/bin/engsys"
printf 'refs/heads/fixture %s refs/heads/fixture 0000000000000000000000000000000000000000\n' "$stale_revision" >"$temporary/refs"
printf 'refs/heads/deleted 0000000000000000000000000000000000000000 refs/heads/deleted %s\n' "$stale_revision" >>"$temporary/refs"
(cd "$project" && sh "$system_root/.githooks/pre-push" <"$temporary/refs")
[ "$(wc -l <"$project/hook-calls" | tr -d ' ')" = 1 ]
grep -Fq -- "--revision $stale_revision" "$project/hook-calls"
printf 'ok editorial reviews bind one document to its reviewed body and committed revision\n'
