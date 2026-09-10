#!/bin/sh

# Activate the Engineering System for one developer. Run once per machine, from a clone
# of this repository. It only touches the developer's own shell profile and this clone's
# Git hook path; it never writes to a project that adopts the standard.
set -eu

fail() { printf 'install: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'EOF'
Usage:
  ./install.sh [--print] [--profile-file <path>]

  --print                 Show the shell profile line without writing it
  --profile-file <path>   Write to this profile instead of the detected one
EOF
}

system_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
[ -f "$system_root/system.yaml" ] && [ -x "$system_root/bin/engsys" ] \
  || fail "run this script from a clone of the Engineering System repository"

print_only=false
profile_file=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --print) print_only=true; shift ;;
    --profile-file) [ "$#" -ge 2 ] || fail '--profile-file requires a value'; profile_file=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

# Git Bash 는 언제나 로그인 셸로 뜨고, .bash_profile -> .bash_login -> .profile 중 처음 있는
# 파일 하나만 읽는다. 이미 있는 그 파일에 쓰지 않으면 새 터미널에서 활성화되지 않는다.
bash_profile_file() {
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      for candidate in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
        [ -f "$candidate" ] && { printf '%s' "$candidate"; return 0; }
      done
      printf '%s' "$HOME/.bash_profile"
      ;;
    *)
      if [ -f "$HOME/.bash_profile" ]; then printf '%s' "$HOME/.bash_profile"
      else printf '%s' "$HOME/.bashrc"; fi
      ;;
  esac
}

if [ -z "$profile_file" ]; then
  # Git Bash 의 $SHELL 은 /bin/bash.exe 다. 확장자를 떼지 않으면 bash 분기에 걸리지 않고
  # 없던 .profile 을 새로 만들어 거기에 쓴다.
  shell_name=${SHELL##*/}
  case "$shell_name" in
    *.exe) shell_name=${shell_name%.exe} ;;
  esac
  case "$shell_name" in
    zsh) profile_file="${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash) profile_file=$(bash_profile_file) ;;
    *) profile_file="$HOME/.profile" ;;
  esac
fi

marker='# Engineering System'
line="eval \"\$($system_root/bin/engsys shellenv)\""

if [ "$print_only" = true ]; then
  printf '%s\n%s\n' "$marker" "$line"
  exit 0
fi

if [ -f "$profile_file" ] && grep -Fq 'bin/engsys shellenv' "$profile_file"; then
  existing=$(grep -F 'bin/engsys shellenv' "$profile_file" | head -1)
  if [ "$existing" = "$line" ]; then
    printf 'ok    shell profile already activates this checkout: %s\n' "$profile_file"
  else
    printf 'warn  shell profile activates a different checkout: %s\n' "$profile_file"
    printf '      %s\n' "$existing"
    printf '      remove that line first if you meant to use %s\n' "$system_root"
  fi
else
  mkdir -p "$(dirname "$profile_file")"
  printf '\n%s\n%s\n' "$marker" "$line" >>"$profile_file"
  printf 'ok    added the activation line to %s\n' "$profile_file"
fi

if [ "$(git -C "$system_root" config --get core.hooksPath 2>/dev/null || true)" = .githooks ]; then
  printf 'ok    push gate already registered in this checkout\n'
else
  git -C "$system_root" config core.hooksPath .githooks
  printf 'ok    registered the push gate in this checkout\n'
fi

printf '\nOpen a new shell, or run this once in the current one:\n  %s\n\n' "$line"

# Report the state the developer will have after the profile is sourced.
PATH="$system_root/bin:$PATH" "$system_root/bin/engsys" doctor --project "$system_root"
