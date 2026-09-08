# Shared by the docs-gov Claude Code hooks. Reads the hook payload from stdin and resolves the
# edited file to a project-relative path. Sourced, never executed on its own.

read_hook_target() {
  hook_input=$(cat)
  file_path=$(printf '%s' "$hook_input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  cwd=$(printf '%s' "$hook_input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  project_dir=${CLAUDE_PROJECT_DIR:-}

  # Claude가 worktree 또는 하위 디렉터리에서 작업하면 hook input의 cwd가 실제 checkout을
  # 가리킨다. Git으로 root를 찾을 수 있을 때만 그것을 우선한다.
  if [ -n "$cwd" ] && git -C "$cwd" rev-parse --show-toplevel >/dev/null 2>&1; then
    project_dir=$(git -C "$cwd" rev-parse --show-toplevel)
    current_dir=$(CDPATH= cd -- "$cwd" && pwd -P)
    case "$file_path" in
      "$cwd"/*) file_path="$current_dir/${file_path#"$cwd"/}" ;;
    esac
  fi

  # Edit·Write는 absolute 또는 project-relative path를 받을 수 있다. 선언은 portable한
  # project-relative path만 쓰므로 absolute path를 여기서 맞춘다.
  case "$file_path" in
    /*)
      file_dir=${file_path%/*}
      file_name=${file_path##*/}
      if [ -n "$file_dir" ] && [ -d "$file_dir" ]; then
        file_path="$(CDPATH= cd -- "$file_dir" && pwd)/$file_name"
      fi
      ;;
  esac
  case "$file_path" in
    "$project_dir"/*) file_path=${file_path#"$project_dir"/} ;;
  esac
}
