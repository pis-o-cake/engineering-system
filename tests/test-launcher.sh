#!/bin/sh

set -eu

source_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)
cleanup() {
  cleanup_status=$?
  rm -rf "$test_dir"
  trap - 0 1 2 15
  exit "$cleanup_status"
}
trap cleanup 0 1 2 15

system_copy="$test_dir/system"
project_dir="$test_dir/project"
fake_bin="$test_dir/fake-bin"
cache_dir="$test_dir/cache"
git clone -q "$source_root" "$system_copy"

# The source checkout can contain the change being tested. Copy it into an isolated Git history so
# resolver and launcher tests always exercise the same clean, revision-locked tree.
(cd "$source_root" && tar --exclude=.git -cf - .) | (cd "$system_copy" && tar -xf -)
git -C "$system_copy" config user.email fixture@example.test
git -C "$system_copy" config user.name fixture
git -C "$system_copy" add -A
# 검사 대상이 이미 커밋돼 있으면 이 fixture commit은 비어 있다. clean checkout(CI)에서도
# 같은 경로를 타야 하므로 빈 commit을 허용한다.
git -C "$system_copy" commit -q --allow-empty -m 'test: package adapter fixture'
plugin_revision=$(git -C "$system_copy" rev-parse HEAD)
printf '%s\n' 'launcher fixture marker' >"$system_copy/.launcher-fixture"
git -C "$system_copy" add .launcher-fixture
git -C "$system_copy" commit -qm 'test: launcher cache fixture'

mkdir -p "$project_dir"
git -C "$project_dir" init -q
ENGSYS_SYSTEM_ROOT="$system_copy" "$system_copy/bin/engsys" init \
  --project "$project_dir" \
  --name launcher-fixture \
  --verify 'printf project-verification'

shellenv=$(ENGSYS_SYSTEM_ROOT="$system_copy" "$system_copy/bin/engsys" shellenv)
printf '%s\n' "$shellenv" | grep -Fq "export PATH='$system_copy/bin':"

mkdir -p "$fake_bin"
cat >"$fake_bin/claude" <<'EOF'
#!/bin/sh
printf '%s\n' "$@"
printf 'ENGSYS_PLUGIN_ROOT=%s\n' "${ENGSYS_PLUGIN_ROOT:-}"
printf 'cwd=%s\n' "$(pwd)"
EOF
chmod +x "$fake_bin/claude"

launch_output=$(PATH="$fake_bin:$PATH" ENGSYS_SYSTEM_ROOT="$system_copy" ENGSYS_CACHE_DIR="$cache_dir" \
  "$system_copy/bin/engsys" claude --project "$project_dir" --resume)
printf '%s\n' "$launch_output" | grep -Fxq -- '--plugin-dir'
plugin_root=$(printf '%s\n' "$launch_output" | awk '/^--plugin-dir$/ { getline; print; exit }')
[ -n "$plugin_root" ]
[ -f "$plugin_root/.claude-plugin/plugin.json" ]
[ -f "$plugin_root/hooks/hooks.json" ]
[ -x "$plugin_root/bin/engsys" ]
[ -f "$plugin_root/packages/docs-gov/policy.yaml" ]
[ -f "$plugin_root/packages/pipeline/claude-code/skills/verify/SKILL.md" ]
grep -Fq 'packages/docs-gov/claude-code/skills/documentation-impact' "$plugin_root/.claude-plugin/plugin.json"
grep -Fq 'packages/docs-gov/claude-code/hooks/block-generated-edit.sh' "$plugin_root/hooks/hooks.json"

# Skill의 Bash 명령은 launcher가 export한 변수와 project cwd에만 의존할 수 있다.
printf '%s\n' "$launch_output" | grep -Fxq "ENGSYS_PLUGIN_ROOT=$plugin_root"
printf '%s\n' "$launch_output" | grep -Fxq "cwd=$project_dir"

# Wrapper는 인자를 그대로 전달해야 한다 (literal "$@" 회귀 방지).
"$plugin_root/bin/engsys" check --project "$project_dir" >/dev/null

# CLAUDE_PLUGIN_ROOT·CLAUDE_PROJECT_DIR는 hook 전용이므로 skill 본문에 나타나면 안 된다.
if find "$plugin_root/packages" -path '*/skills/*' -name 'SKILL.md' \
    -exec grep -lE 'CLAUDE_PLUGIN_ROOT|CLAUDE_PROJECT_DIR' {} + 2>/dev/null | grep -q .; then
  printf '%s\n' 'packaged skill references a hook-only environment variable' >&2
  exit 1
fi

if command -v claude >/dev/null 2>&1; then
  claude plugin validate "$source_root" --strict
  claude plugin validate "$plugin_root" --strict
fi

# An old lock can omit a newly introduced package. The local plugin view must follow the lock rather
# than silently exposing pipeline skills from the current profile.
sed '/^  pipeline:$/,/^    revision:/d' "$project_dir/.engsys/lock.yaml" >"$project_dir/.engsys/lock.yaml.next"
mv "$project_dir/.engsys/lock.yaml.next" "$project_dir/.engsys/lock.yaml"
filtered_output=$(PATH="$fake_bin:$PATH" ENGSYS_SYSTEM_ROOT="$system_copy" ENGSYS_CACHE_DIR="$cache_dir" \
  "$system_copy/bin/engsys" claude --project "$project_dir")
filtered_root=$(printf '%s\n' "$filtered_output" | awk '/^--plugin-dir$/ { getline; print; exit }')
[ "$filtered_root" != "$plugin_root" ]
[ ! -e "$filtered_root/packages/pipeline" ]
if grep -Fq 'packages/pipeline/' "$filtered_root/.claude-plugin/plugin.json"; then
  printf '%s\n' 'filtered plugin view retained pipeline skill' >&2
  exit 1
fi

# A project lock may point at an older system revision. Resolver must prepare that revision before
# materializing the profile-specific plugin view.
awk -v revision="$plugin_revision" '
  !changed && /^  revision:/ { print "  revision: '\''" revision "'\''"; changed = 1; next }
  { print }
' "$project_dir/.engsys/lock.yaml" >"$project_dir/.engsys/lock.yaml.next"
mv "$project_dir/.engsys/lock.yaml.next" "$project_dir/.engsys/lock.yaml"
cached=$(ENGSYS_SYSTEM_ROOT="$system_copy" ENGSYS_CACHE_DIR="$cache_dir" \
  "$system_copy/bin/engsys" resolve --project "$project_dir")
[ "$cached" = "$cache_dir/releases/$plugin_revision" ]
[ "$(git -C "$cached" rev-parse HEAD)" = "$plugin_revision" ]
cached_output=$(PATH="$fake_bin:$PATH" ENGSYS_SYSTEM_ROOT="$system_copy" ENGSYS_CACHE_DIR="$cache_dir" \
  "$system_copy/bin/engsys" claude --project "$project_dir")
cached_root=$(printf '%s\n' "$cached_output" | awk '/^--plugin-dir$/ { getline; print; exit }')
grep -Fxq "revision=$plugin_revision" "$cached_root/.engsys-view"
grep -Fq "$cached/bin/engsys" "$cached_root/bin/engsys"
