#!/bin/sh

# Sourced by bin/engsys; shared runtime helpers and system_root are supplied by the entrypoint.

require_plugin_relative_path() {
  case "$1" in
    ''|/*|..|../*|*/../*|*/..) die "path must be plugin-relative: $1" ;;
  esac
}

package_adapter_skills() {
  source_root=$1
  package=$2
  manifest="$source_root/packages/$package/package.yaml"
  [ -f "$manifest" ] || die "package is missing from locked system revision: $package"

  awk '
    /^  claude-code:$/ { in_adapter = 1; in_skills = 0; next }
    in_adapter && /^  [A-Za-z0-9_-]+:$/ { exit }
    in_adapter && /^    skills:$/ { in_skills = 1; next }
    in_skills && /^    [A-Za-z0-9_-]+:$/ { exit }
    in_skills && /^      - / {
      sub(/^      -[[:space:]]*/, "")
      print
    }
  ' "$manifest"
}

package_adapter_hooks() {
  source_root=$1
  package=$2
  manifest="$source_root/packages/$package/package.yaml"
  [ -f "$manifest" ] || die "package is missing from locked system revision: $package"

  awk '
    function emit() {
      # IFS 로 TAB 을 쓰면 빈 field 가 사라진다. matcher 없는 event 는 '-' 로 표시해 실어 보낸다.
      if (event != "") print event "\t" (matcher == "" ? "-" : matcher) "\t" command "\t" timeout
      event = matcher = command = timeout = ""
    }
    /^  claude-code:$/ { in_adapter = 1; in_hooks = 0; next }
    in_adapter && /^  [A-Za-z0-9_-]+:$/ { in_adapter = 0; in_hooks = 0; next }
    in_adapter && /^    hooks:$/ { in_hooks = 1; next }
    in_hooks && /^    [A-Za-z0-9_-]+:$/ { in_hooks = 0; next }
    in_hooks && /^      - event:[[:space:]]*/ {
      emit()
      event = $0
      sub(/^      - event:[[:space:]]*/, "", event)
      next
    }
    in_hooks && /^        matcher:[[:space:]]*/ {
      matcher = $0
      sub(/^        matcher:[[:space:]]*/, "", matcher)
      next
    }
    in_hooks && /^        command:[[:space:]]*/ {
      command = $0
      sub(/^        command:[[:space:]]*/, "", command)
      next
    }
    in_hooks && /^        timeout:[[:space:]]*/ {
      timeout = $0
      sub(/^        timeout:[[:space:]]*/, "", timeout)
      next
    }
    END { emit() }
  ' "$manifest"
}

source_plugin_version() {
  sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$1/.claude-plugin/plugin.json" | sed -n '1p'
}

write_plugin_manifest() {
  source_root=$1
  packages=$2
  destination=$3
  version=$(source_plugin_version "$source_root")
  [ -n "$version" ] || die "plugin manifest has no version"

  {
    cat <<EOF
{
  "\$schema": "https://json.schemastore.org/claude-code-plugin-manifest.json",
  "name": "engsys",
  "displayName": "Engineering System",
  "version": "$version",
  "description": "Lock-aware Engineering System workflows.",
  "author": { "name": "pis-o-cake" },
  "repository": "https://github.com/pis-o-cake/engineering-system",
  "skills": [
EOF
    first=true
    for package in $packages; do
      skill_paths=$(package_adapter_skills "$source_root" "$package")
      for skill_path in $skill_paths; do
        require_plugin_relative_path "$skill_path"
        [ -f "$source_root/packages/$package/$skill_path/SKILL.md" ] \
          || die "package skill is missing: $package/$skill_path"
        if [ "$first" = true ]; then
          first=false
        else
          printf ',\n'
        fi
        printf '    "./packages/%s/%s"' "$package" "$skill_path"
      done
    done
    printf '\n  ],\n'
    printf '%s\n' '  "hooks": "./hooks/hooks.json"'
    printf '%s\n' '}'
  } >"$destination"
}

write_plugin_hooks() {
  source_root=$1
  packages=$2
  destination=$3
  entries="$destination.entries.$$"
  : >"$entries"

  for package in $packages; do
    package_adapter_hooks "$source_root" "$package" \
      | while IFS="$(printf '\t')" read -r event matcher command timeout; do
          [ -n "$event" ] || continue
          require_plugin_relative_path "$command"
          case "$event" in ''|*[!A-Za-z]*) die "package hook has invalid event: $event" ;; esac
          case "$matcher" in ''|*[!A-Za-z'|-']*) die "package hook has invalid matcher: $matcher" ;; esac
          case "$timeout" in ''|*[!0-9]*) die "package hook has invalid timeout: $timeout" ;; esac
          [ -f "$source_root/packages/$package/$command" ] \
            || die "package hook handler is missing: $package/$command"
          printf '%s\t%s\t%s\t%s\t%s\n' "$package" "$event" "$matcher" "$command" "$timeout" >>"$entries"
        done
  done

  {
    printf '%s\n' '{'
    printf '%s\n' '  "hooks": {'
    events=$(cut -f2 "$entries" | LC_ALL=C sort -u)
    first_event=true
    for event in $events; do
      if [ "$first_event" = true ]; then
        first_event=false
      else
        printf ',\n'
      fi
      printf '    "%s": [\n' "$event"
      first_hook=true
      while IFS="$(printf '\t')" read -r package entry_event matcher command timeout; do
        [ "$entry_event" = "$event" ] || continue
        if [ "$first_hook" = true ]; then
          first_hook=false
        else
          printf ',\n'
        fi
        printf '%s\n' '      {'
        [ "$matcher" = - ] || printf '        "matcher": "%s",\n' "$matcher"
        cat <<EOF
        "hooks": [
          {
            "type": "command",
            "command": "sh \"\${CLAUDE_PLUGIN_ROOT}/packages/$package/$command\"",
            "timeout": $timeout
          }
        ]
      }
EOF
      done <"$entries"
      printf '\n    ]'
    done
    printf '\n  }\n}\n'
  } >"$destination"
  rm -f "$entries"
}

write_plugin_wrapper() {
  source_root=$1
  destination=$2
  cat >"$destination" <<EOF
#!/bin/sh
export ENGSYS_SYSTEM_ROOT=$(shell_quote "$source_root")
exec $(shell_quote "$source_root/bin/engsys") "\$@"
EOF
  chmod +x "$destination"
}

plugin_view_is_ready() {
  view=$1
  revision=$2
  profile=$3
  [ -f "$view/.engsys-view" ] && [ -f "$view/.claude-plugin/plugin.json" ] \
    && [ -f "$view/hooks/hooks.json" ] && [ -x "$view/bin/engsys" ] \
    && grep -Fxq "revision=$revision" "$view/.engsys-view" \
    && grep -Fxq "profile=$profile" "$view/.engsys-view"
}

materialize_plugin_view() {
  project_dir=$1
  source_root=$2
  lock="$project_dir/.engsys/lock.yaml"
  contract="$project_dir/.engsys/project.yaml"
  revision=$(lock_system_revision "$lock")
  profile=$(project_profile "$contract")
  require_profile_name "$profile"
  packages=$(lock_package_names "$lock")
  [ -n "$packages" ] || die "lock has no packages"
  package_key=$(printf '%s\n' "$packages" | LC_ALL=C sort | cksum | awk '{print $1}')
  view="$(cache_root)/plugins/$revision/$profile-$package_key"

  if [ -e "$view" ]; then
    plugin_view_is_ready "$view" "$revision" "$profile" && {
      printf '%s\n' "$view"
      return
    }
    die "cached plugin view is incomplete or incompatible: $view"
  fi

  temporary="$view.tmp.$$"
  cleanup_view_temporary() {
    view_status=$?
    rm -rf "$temporary"
    trap - 0 1 2 15
    exit "$view_status"
  }
  trap cleanup_view_temporary 0 1 2 15
  mkdir -p "$temporary/.claude-plugin" "$temporary/bin" "$temporary/hooks" "$temporary/packages"
  for package in $packages; do
    [ -d "$source_root/packages/$package" ] \
      || die "package is missing from locked system revision: $package"
    cp -R "$source_root/packages/$package" "$temporary/packages/$package"
  done
  write_plugin_manifest "$source_root" "$packages" "$temporary/.claude-plugin/plugin.json"
  write_plugin_hooks "$source_root" "$packages" "$temporary/hooks/hooks.json"
  write_plugin_wrapper "$source_root" "$temporary/bin/engsys"
  {
    printf 'revision=%s\n' "$revision"
    printf 'profile=%s\n' "$profile"
    printf '%s\n' "$packages"
  } >"$temporary/.engsys-view"
  mkdir -p "$(dirname "$view")"
  if [ -e "$view" ]; then
    # 동시 실행이 같은 view를 먼저 완성했다. 승자를 쓰고 임시본은 버린다.
    rm -rf "$temporary"
    trap - 0 1 2 15
    plugin_view_is_ready "$view" "$revision" "$profile" \
      || die "cached plugin view is incomplete or incompatible: $view"
    printf '%s\n' "$view"
    return
  fi
  mv "$temporary" "$view"
  trap - 0 1 2 15
  printf '%s\n' "$view"
}

resolve_locked_plugin() {
  project_dir=$1
  lock="$project_dir/.engsys/lock.yaml"
  [ -f "$lock" ] || die "missing .engsys/lock.yaml"
  revision=$(lock_system_revision "$lock")
  [ -n "$revision" ] || die "lock has no system revision"
  require_safe_revision "$revision"

  if [ "$(system_revision)" = "$revision" ] && system_is_clean; then
    printf '%s\n' "$system_root"
    return
  fi

  cache_dir="$(cache_root)/releases/$revision"
  if [ -d "$cache_dir" ]; then
    cached_revision=$(git -C "$cache_dir" rev-parse HEAD 2>/dev/null || true)
    [ "$cached_revision" = "$revision" ] || die "cached revision is invalid: $cache_dir"
    [ -z "$(git -C "$cache_dir" status --porcelain --untracked-files=no 2>/dev/null)" ] \
      || die "cached revision has local changes: $cache_dir"
    printf '%s\n' "$cache_dir"
    return
  fi

  if ! git -C "$system_root" cat-file -e "$revision^{commit}" 2>/dev/null; then
    git -C "$system_root" fetch --quiet origin
  fi
  git -C "$system_root" cat-file -e "$revision^{commit}" 2>/dev/null \
    || die "locked revision is unavailable from origin: $revision"
  mkdir -p "$(cache_root)/releases"
  git -C "$system_root" worktree add --quiet --detach "$cache_dir" "$revision" \
    || die "could not prepare cached revision: $revision"
  printf '%s\n' "$cache_dir"
}

