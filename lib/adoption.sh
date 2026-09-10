#!/bin/sh

# Sourced by bin/engsys; shared runtime helpers and system_root are supplied by the entrypoint.

hook_names() { printf '%s\n' commit-msg pre-push; }
hook_record() { printf '%s/.engsys/hooks.txt' "$1"; }

hook_recorded() {
  hook_record_file=$(hook_record "$1")
  [ -f "$hook_record_file" ] || return 0
  awk -v name="$2" -v column="$3" '$1 == name { print $column; exit }' "$hook_record_file"
}

hook_state() {
  hook_project=$1
  hook_name=$2
  hook_template="$system_root/templates/project/.githooks/$hook_name"
  hook_installed="$hook_project/.githooks/$hook_name"
  [ -f "$hook_template" ] || { printf 'unknown'; return; }
  [ -f "$hook_installed" ] || { printf 'missing'; return; }
  template_hash=$(git hash-object -- "$hook_template")
  installed_hash=$(git hash-object -- "$hook_installed")
  [ "$installed_hash" != "$template_hash" ] || { printf 'current'; return; }

  recorded_template=$(hook_recorded "$hook_project" "$hook_name" 2)
  recorded_installed=$(hook_recorded "$hook_project" "$hook_name" 3)
  # 기준 기록이 없으면 사본이 갈라진 이유를 알 수 없다. 프로젝트가 고쳤다고 단정하면
  # template 이 움직인 경우에도 같은 문장이 나와 읽는 사람이 원인을 반대로 잡는다.
  [ -n "$recorded_installed" ] || { printf 'unrecorded'; return; }
  [ "$installed_hash" = "$recorded_installed" ] || { printf 'modified'; return; }
  [ "$recorded_template" != "$template_hash" ] || { printf 'owned'; return; }
  [ "$recorded_installed" = "$recorded_template" ] || { printf 'modified'; return; }
  printf 'outdated'
}

record_hook_baseline() {
  hook_project=$1
  hook_name=$2
  hook_template_hash=$3
  hook_installed_hash=$4
  hook_record_file=$(hook_record "$hook_project")
  mkdir -p "$(dirname "$hook_record_file")"
  if [ -f "$hook_record_file" ]; then
    awk -v name="$hook_name" '$1 != name' "$hook_record_file" >"$hook_record_file.next"
  else
    : >"$hook_record_file.next"
  fi
  printf '%s\t%s\t%s\n' "$hook_name" "$hook_template_hash" "$hook_installed_hash" \
    >>"$hook_record_file.next"
  LC_ALL=C sort -o "$hook_record_file.next" "$hook_record_file.next"
  mv -f "$hook_record_file.next" "$hook_record_file"
}

# core.hooksPath 는 .git/config 에 있어 commit 되지 않는다. hook 파일을 받은 팀원도 이것을
# 세우지 않으면 git 이 그 파일을 부르지 않는다. 게이트가 통째로 사라지는 지점이다.
register_hooks_path() {
  hooks_dir=$1
  current_hooks_path=$(git -C "$hooks_dir" config --get core.hooksPath 2>/dev/null || true)
  if [ -z "$current_hooks_path" ]; then
    git -C "$hooks_dir" config core.hooksPath .githooks
    printf 'registered core.hooksPath .githooks\n'
  elif [ "$current_hooks_path" = .githooks ]; then
    printf 'core.hooksPath is already .githooks\n'
  else
    printf 'left core.hooksPath as %s; run the gate from there or change it yourself\n' \
      "$current_hooks_path"
  fi
}

hooks() {
  project_dir=$(pwd)
  hooks_action=${1:-status}
  case "$hooks_action" in
    status|update) shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown hooks action: $hooks_action" ;;
  esac
  hooks_force=false
  hooks_adopt=false
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project) require_value "$@"; project_dir=$2; shift 2 ;;
      --force) hooks_force=true; shift ;;
      --adopt) hooks_adopt=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown hooks option: $1" ;;
    esac
  done
  project_dir=$(normalise_project_dir "$project_dir")
  require_worktree "$project_dir"
  hooks_pending=0

  for hook_name in $(hook_names); do
    state=$(hook_state "$project_dir" "$hook_name")
    template="$system_root/templates/project/.githooks/$hook_name"
    installed="$project_dir/.githooks/$hook_name"
    # --adopt 는 사본을 그대로 두고 현재 template 을 확인한 것으로만 기록한다.
    if [ "$hooks_action" = update ] && [ "$hooks_adopt" = true ] \
      && [ "$state" != missing ] && [ "$state" != current ] && [ "$state" != unknown ]; then
      record_hook_baseline "$project_dir" "$hook_name" "$(git hash-object -- "$template")" \
        "$(git hash-object -- "$installed")"
      printf 'adopted  %s — 현재 사본을 유지한다. 이후 template이 바뀔 때 다시 알린다\n' "$hook_name"
      continue
    fi
    install_hook() {
      mkdir -p "$project_dir/.githooks"
      cp "$template" "$installed"
      chmod +x "$installed"
      hook_new_hash=$(git hash-object -- "$template")
      record_hook_baseline "$project_dir" "$hook_name" "$hook_new_hash" "$hook_new_hash"
    }
    case "$state" in
      current) printf 'ok       %s는 현재 template과 같다\n' "$hook_name" ;;
      owned) printf 'ok       %s는 프로젝트가 소유한 사본이다. 현재 template을 확인한 상태다\n' "$hook_name" ;;
      missing)
        if [ "$hooks_action" = update ]; then
          install_hook
          printf 'wrote    %s\n' "$hook_name"
        else
          printf 'missing  %s — engsys hooks update로 설치한다\n' "$hook_name"
          hooks_pending=$((hooks_pending + 1))
        fi
        ;;
      outdated)
        if [ "$hooks_action" = update ]; then
          install_hook
          printf 'updated  %s\n' "$hook_name"
        else
          printf 'outdated %s — 사본을 고치지 않았고 template이 바뀌었다. engsys hooks update로 갱신한다\n' "$hook_name"
          hooks_pending=$((hooks_pending + 1))
        fi
        ;;
      modified)
        if [ "$hooks_action" = update ] && [ "$hooks_force" = true ]; then
          install_hook
          printf 'replaced %s — 프로젝트의 수정을 버렸다\n' "$hook_name"
        else
          printf 'modified %s — 프로젝트가 고친 사본이다. 갱신하면 그 수정이 사라진다\n' "$hook_name"
          printf '         차이: diff %s %s\n' "$installed" "$template"
          printf '         갱신: engsys hooks update --force · 유지: engsys hooks update --adopt\n'
          hooks_pending=$((hooks_pending + 1))
        fi
        ;;
      unrecorded)
        if [ "$hooks_action" = update ] && [ "$hooks_force" = true ]; then
          install_hook
          printf 'replaced %s — 기준 기록이 없던 사본을 template으로 덮었다\n' "$hook_name"
        else
          printf 'unrecorded %s — 사본이 template과 다르지만 기준 기록이 없다. 프로젝트가 고친 것인지 template이 바뀐 것인지 engsys는 모른다\n' "$hook_name"
          printf '         차이: diff %s %s\n' "$installed" "$template"
          printf '         차이가 프로젝트의 것이면: engsys hooks update --adopt\n'
          printf '         차이가 template의 것이면: engsys hooks update --force\n'
          hooks_pending=$((hooks_pending + 1))
        fi
        ;;
      *) printf 'unknown  %s — template이 이 revision에 없다\n' "$hook_name" ;;
    esac
  done

  if [ "$hooks_action" = update ]; then
    register_hooks_path "$project_dir"
    return 0
  fi
  [ "$hooks_pending" -eq 0 ] || return 1
}

# 채택은 여러 단계이고 각 단계가 무엇을 바꾸는지 사람이 보고 넘어가야 한다. 다른 명령은
# 비대화형으로 남기고, 이 명령만 단계마다 확인하고 실행한 뒤 다시 검사한다.
setup_step=0
# 어느 단계에서 멈췄는지는 subshell 밖에서 읽어야 한다. 실패하면 그 shell 이 사라지기 때문이다.
setup_say() {
  setup_step=$((setup_step + 1))
  printf '\n[%s] %s\n' "$setup_step" "$1"
  [ -z "${setup_state:-}" ] || printf '%s\t%s\n' "$setup_step" "$1" >"$setup_state"
}
setup_ok() { printf '    ok   %s\n' "$1"; }
setup_note() { printf '    ·    %s\n' "$1"; }
setup_warn() { printf '    warn %s\n' "$1"; }

setup_ask() {
  [ "$setup_yes" = false ] || { printf '    -> %s [자동 승인]\n' "$1"; return 0; }
  printf '    -> %s [y/N] ' "$1"
  read -r setup_answer || setup_answer=n
  case "$setup_answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# 실패하면 어디서 왜 멈췄는지와 다음에 무엇을 할지 남긴다. 한 줄만 찍고 끝나면 터미널을
# 닫는 순간 사라지고, 무엇을 고쳐야 하는지도 알 수 없다.
setup() {
  setup_state=$(mktemp)
  setup_status=$(mktemp)
  setup_target=$(mktemp)
  setup_log="$(printf '%s' "${TMPDIR:-/tmp}" | sed 's|/*$||')/engsys-setup-$$.log"
  printf '1\n' >"$setup_status"
  printf '0\t시작 전\n' >"$setup_state"
  printf '%s\n' "$(pwd)" >"$setup_target"

  ( setup_body "$@" && printf '0\n' >"$setup_status" ) 2>&1 | tee "$setup_log"

  setup_result=$(cat "$setup_status")
  setup_where=$(cut -f2 "$setup_state")
  setup_where_number=$(cut -f1 "$setup_state")
  setup_project_dir=$(cat "$setup_target")
  rm -f "$setup_state" "$setup_status" "$setup_target"

  if [ "$setup_result" = 0 ]; then
    printf '\n전체 기록: %s\n' "$setup_log"
    return 0
  fi

  printf '\n%s\n' '----------------------------------------------------------------'
  printf '멈춘 곳: [%s] %s\n' "$setup_where_number" "$setup_where"
  printf '위의 마지막 오류 줄이 이유다. 아무것도 되돌리지 않았으니 고치고 다시 실행하면 된다.\n\n'
  printf '  지금 상태 보기 : engsys doctor --project %s\n' "$setup_project_dir"
  printf '  다시 실행      : engsys setup --project %s\n' "$setup_project_dir"
  printf '  전체 기록      : %s\n' "$setup_log"
  printf '%s\n' '----------------------------------------------------------------'
  return 1
}

setup_body() {
  project_dir=$(pwd)
  setup_yes=false
  setup_project_given=false
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project) require_value "$@"; project_dir=$2; setup_project_given=true; shift 2 ;;
      --yes) setup_yes=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown setup option: $1" ;;
    esac
  done
  project_dir=$(normalise_project_dir "$project_dir")
  [ -z "${setup_target:-}" ] || printf '%s\n' "$project_dir" >"$setup_target"
  # 시스템 checkout 안에서 --project 없이 실행하면 표준 자신을 대상으로 잡는다. 거의 언제나
  # 실수이므로 무엇을 해야 하는지 알린다.
  if [ "$project_dir" = "$system_root" ] && [ "$setup_project_given" = false ]; then
    die "대상이 표준 저장소 자신이다. 붙일 프로젝트 디렉토리에서 실행하거나 --project 를 준다"
  fi
  # 물어볼 수 없는데 진행하면 조용히 전부 거절한 것과 같아진다. 그 상태로 끝내지 않는다.
  [ -t 0 ] || [ "$setup_yes" = true ] \
    || die '터미널이 없어 단계마다 물어볼 수 없다. --yes 를 주거나 각 명령을 직접 실행한다'
  printf 'Engineering System 채택을 단계별로 진행한다.\n'
  printf '각 단계는 먼저 확인하고, 바꿀 것을 보여 준 뒤, 동의를 받고 실행한다.\n'
  printf '시스템: %s\n대상  : %s\n' "$system_root" "$project_dir"

  setup_say '전제 도구'
  command -v git >/dev/null 2>&1 || die 'git 이 없다. 먼저 설치한다'
  setup_ok "git $(git --version 2>/dev/null | awk '{print $3}')"
  if command -v python3 >/dev/null 2>&1; then
    setup_ok 'python3 (커밋 subject 글자 수를 정확히 센다)'
  else
    setup_warn 'python3 없음 — UTF-8 로케일의 wc 로 떨어진다. 동작은 한다'
  fi
  command -v claude >/dev/null 2>&1 && setup_ok 'Claude Code' \
    || setup_warn 'Claude Code 없음 — engsys claude 만 못 쓴다'

  setup_say '시스템 checkout'
  revision=$(system_revision)
  [ "$revision" != unversioned ] || die '시스템 checkout 이 Git 저장소가 아니다'
  setup_ok "revision $revision"
  system_is_clean || setup_warn '수정된 파일이 있다. lock 은 commit 만 가리킨다'
  if git -C "$system_root" merge-base --is-ancestor "$revision" origin/main 2>/dev/null; then
    setup_ok 'origin/main 에서 도달 가능한 revision 이다'
  else
    setup_warn 'origin/main 에 없는 revision 이다. 팀원이 이 lock 을 받지 못한다'
  fi

  setup_say '개발자 활성화 (이 머신에 한 번)'
  resolved=$(command -v engsys 2>/dev/null || true)
  if [ -n "$resolved" ] && same_file "$resolved" "$system_root/bin/engsys"; then
    setup_ok "engsys 가 PATH 에 있다: $resolved"
  else
    setup_note 'PATH 에 없다. install.sh 가 shell profile 한 줄과 이 clone 의 hook 경로를 설정한다'
    if setup_ask 'install.sh 실행'; then
      sh "$system_root/install.sh" || die 'install.sh 가 실패했다'
    else
      setup_warn '건너뛴다. 새 shell 에서 engsys 를 찾지 못하면 다시 실행한다'
    fi
  fi

  setup_say '대상 프로젝트'
  require_worktree "$project_dir"
  setup_ok "Git worktree 다: $project_dir"
  if [ -f "$project_dir/.engsys/project.yaml" ]; then
    setup_ok '계약이 이미 있다. 새로 만들지 않는다'
  else
    setup_note '계약이 없다. 감지 결과를 먼저 보여 준다'
    printf '\n'
    "$system_root/bin/engsys" init --project "$project_dir" --detect --hooks --dry-run \
      || die '감지에 실패했다. --verify 로 검증 명령을 직접 준다'
    printf '\n'
    if setup_ask '위 내용으로 계약과 Git hook 생성'; then
      "$system_root/bin/engsys" init --project "$project_dir" --detect --hooks || return 1
    else
      setup_warn '건너뛴다. engsys init 을 직접 실행한 뒤 이 명령을 다시 돌린다'
      return 0
    fi
  fi

  setup_say 'Git hook'
  for hook_name in $(hook_names); do
    setup_note "$hook_name: $(hook_state "$project_dir" "$hook_name")"
  done
  if "$system_root/bin/engsys" hooks status --project "$project_dir" >/dev/null 2>&1; then
    setup_ok '사본이 현재 template 과 맞다'
  elif setup_ask 'hook 설치·갱신 (고친 사본은 건드리지 않는다)'; then
    "$system_root/bin/engsys" hooks update --project "$project_dir" \
      || setup_warn 'hook 갱신이 끝나지 않았다. 위 출력을 보고 직접 처리한다'
  fi
  hooks_path=$(git -C "$project_dir" config --get core.hooksPath 2>/dev/null || true)
  if [ -n "$hooks_path" ]; then
    setup_ok "core.hooksPath = $hooks_path"
  else
    setup_note 'core.hooksPath 가 없다. 이 설정은 commit 되지 않으므로 clone 한 사람마다 세운다'
    if setup_ask 'core.hooksPath 를 .githooks 로 설정'; then
      register_hooks_path "$project_dir"
    else
      setup_warn '건너뛴다. hook 파일이 있어도 git 이 부르지 않는다'
    fi
  fi

  setup_say '검사'
  # 진단은 stdout 으로도 나온다. 통째로 버리면 실패 원인이 사라진 채 "고쳐라"만 남는다.
  if ! setup_output=$("$system_root/bin/engsys" check --project "$project_dir" 2>&1); then
    [ -z "$setup_output" ] || printf '%s\n' "$setup_output" >&2
    die '계약 검사가 실패했다. 위 오류를 먼저 고친다'
  fi
  setup_ok '계약과 lock 이 engsys check 를 통과한다'
  if setup_ask 'engsys verify 실행 (프로젝트의 native test 포함, 시간이 걸린다)'; then
    "$system_root/bin/engsys" verify --project "$project_dir" || return 1
  else
    setup_note '나중에 engsys verify 로 확인한다'
  fi

  setup_say '최종 진단'
  # 중간 단계가 경고만 내고 넘어갔을 수 있다. 마지막에 한 번 더 전체를 보고, 남은 문제가 있으면
  # 성공으로 끝내지 않는다. 그러지 않으면 FAIL 을 본 사람이 무엇이 남았는지 알 수 없다.
  if "$system_root/bin/engsys" doctor --project "$project_dir"; then
    setup_ok 'doctor 가 고칠 문제를 찾지 못했다'
  else
    setup_warn '위 FAIL 항목이 남아 있다. 각 줄이 실행할 명령을 알려 준다'
    return 1
  fi

  setup_say '남은 것'
  grep -q '^  authoring:' "$project_dir/.engsys/project.yaml" 2>/dev/null \
    && setup_ok '문서 유형 배정이 선언돼 있다' \
    || setup_note '문서 유형 배정이 없다. 문서를 만들 때 documentation.authoring 에 경로를 배정한다'
  grep -q '^  review:' "$project_dir/.engsys/project.yaml" 2>/dev/null \
    && setup_ok '편집 검토 범위가 선언돼 있다' \
    || setup_note '편집 검토 범위가 없다. 실제로 검토한 문서부터 documentation.review.scopes 에 넣는다'
  setup_note '.engsys/ 와 .githooks/ 를 commit 한다. 그래야 팀원이 같은 계약을 받는다'
  setup_note '팀원은 각자 install.sh 를 돌리고 engsys hooks update 로 hook 을 켠다'
  printf '\n%s\n' '상태는 언제든 engsys doctor 로 다시 본다.'
}

doctor_report() {
  case "$1" in
    ok) printf 'ok    %s\n' "$2" ;;
    warn) printf 'warn  %s\n' "$2" ;;
    fail) printf 'FAIL  %s\n' "$2" >&2 ;;
  esac
  [ -z "${3:-}" ] || case "$1" in
    fail) printf '      %s\n' "$3" >&2 ;;
    *) printf '      %s\n' "$3" ;;
  esac
}

same_file() {
  [ -e "$1" ] && [ -e "$2" ] || return 1
  first=$(CDPATH= cd -- "$(dirname "$1")" && pwd -P)/$(basename "$1")
  second=$(CDPATH= cd -- "$(dirname "$2")" && pwd -P)/$(basename "$2")
  [ "$first" = "$second" ]
}

doctor() {
  project_dir=$(pwd)
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project) require_value "$@"; project_dir=$2; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown doctor option: $1" ;;
    esac
  done
  project_dir=$(normalise_project_dir "$project_dir")
  failures=0

  printf '%s\n' "Engineering System: $system_root"
  revision=$(system_revision)
  if [ "$revision" = unversioned ]; then
    doctor_report fail 'system checkout is not a Git repository' \
      "clone the system repository again; a lock cannot record a revision from $system_root"
    failures=$((failures + 1))
  else
    doctor_report ok "system checkout revision $revision"
    system_is_clean || doctor_report warn 'system checkout has uncommitted changes' \
      'a lock records the committed revision, not the working tree'
  fi

  resolved=$(command -v engsys 2>/dev/null || true)
  if [ -z "$resolved" ]; then
    doctor_report fail 'engsys is not on PATH' \
      "add this line to your shell profile: eval \"\$($system_root/bin/engsys shellenv)\""
    failures=$((failures + 1))
  elif same_file "$resolved" "$system_root/bin/engsys"; then
    doctor_report ok "engsys on PATH: $resolved"
  else
    doctor_report warn "engsys on PATH is a different checkout: $resolved" \
      "this run used $system_root/bin/engsys"
  fi

  if command -v claude >/dev/null 2>&1; then
    doctor_report ok 'Claude Code is on PATH'
  else
    doctor_report warn 'Claude Code is not on PATH' \
      'engsys claude needs it; every other command works without it'
  fi

  if [ -d "$system_root/.githooks" ]; then
    hooks_path=$(git -C "$system_root" config --get core.hooksPath 2>/dev/null || true)
    if [ "$hooks_path" = .githooks ]; then
      doctor_report ok 'system push gate is registered'
    else
      doctor_report warn 'system push gate is not registered' \
        "run: git -C $system_root config core.hooksPath .githooks"
    fi
  fi

  printf '\n%s\n' "Project: $project_dir"
  if [ ! -f "$project_dir/.engsys/project.yaml" ]; then
    doctor_report warn 'project has not adopted Engineering System' \
      'run: engsys init --verify <native verify command>'
    printf '\n%s\n' "$failures problem(s) to fix"
    [ "$failures" -eq 0 ] || exit 1
    return
  fi

  if "$system_root/bin/engsys" check --project "$project_dir" >/dev/null 2>&1; then
    doctor_report ok 'project contract and lock pass engsys check'
  else
    doctor_report fail 'project contract or lock does not pass engsys check' \
      "run: engsys check --project $project_dir"
    failures=$((failures + 1))
  fi

  if [ "$project_dir" != "$system_root" ]; then
    # 이 선언이 있으면 팀원은 clone 하고 열기만 해도 skill 과 hook 을 받는다. 없으면 각자
    # 세션을 어떻게 열었는지에 따라 결과가 달라진다.
    if grep -q '"enabledPlugins"' "$project_dir/.claude/settings.json" 2>/dev/null; then
      doctor_report ok 'project declares the Engineering System plugin for any Claude Code session'
      # 선언된 hook 은 engsys 를 PATH 에서 찾는다. plugin 은 배선을 나르고 판정하는 코드는
      # 나르지 않으므로, PATH 가 비면 붙어 있어도 아무것도 판정하지 않는다.
      if command -v engsys >/dev/null 2>&1; then
        doctor_report ok 'the declared hooks can reach engsys on PATH'
      else
        doctor_report fail 'the declared hooks cannot reach engsys; the plugin carries no checker' \
          'run: install.sh in the system checkout, then open a new shell'
        failures=$((failures + 1))
      fi
    else
      doctor_report warn 'project does not declare the Engineering System plugin' \
        "run: engsys init --project $project_dir, or copy templates/project/.claude/settings.json"
    fi
    project_hooks=$(git -C "$project_dir" config --get core.hooksPath 2>/dev/null || true)
    if [ "$project_hooks" = .githooks ] && [ -f "$project_dir/.githooks/pre-push" ]; then
      doctor_report ok 'project push gate is registered'
    else
      doctor_report warn 'project push gate is not registered' \
        "run: engsys init --hooks, or point core.hooksPath at your own gate"
    fi
  fi

  for hook_name in $(hook_names); do
    case "$(hook_state "$project_dir" "$hook_name")" in
      current|owned|unknown) ;;
      missing) doctor_report warn "project hook is not installed: $hook_name" \
        "run: engsys hooks update --project $project_dir" ;;
      outdated) doctor_report warn "project hook is older than the template: $hook_name" \
        "run: engsys hooks update --project $project_dir" ;;
      modified) doctor_report warn "project hook differs from the template: $hook_name" \
        "the project owns it; engsys hooks status shows the options" ;;
      unrecorded) doctor_report warn "project hook differs from the template with no baseline: $hook_name" \
        "run: engsys hooks status --project $project_dir" ;;
    esac
  done

  contract="$project_dir/.engsys/project.yaml"
  lock="$project_dir/.engsys/lock.yaml"
  profile=$(project_profile "$contract")
  if [ -f "$system_root/profiles/$profile.yaml" ]; then
    doctor_report ok "profile $profile exists in this system checkout"
  else
    doctor_report fail "profile is unknown in this system checkout: $profile" \
      'the project needs a system revision that declares this profile'
    failures=$((failures + 1))
  fi

  locked=$(lock_system_revision "$lock")
  if [ -z "$locked" ]; then
    doctor_report fail 'lock has no system revision' 'run: engsys upgrade --apply'
    failures=$((failures + 1))
  elif git -C "$system_root" cat-file -e "$locked^{commit}" 2>/dev/null; then
    doctor_report ok "locked system revision is available: $locked"
    if git -C "$system_root" merge-base --is-ancestor "$locked" origin/main 2>/dev/null; then
      if [ "$locked" = "$(git -C "$system_root" rev-parse origin/main 2>/dev/null)" ]; then
        doctor_report ok 'lock is at origin/main'
      else
        doctor_report warn 'a newer system revision is on origin/main' \
          "review it first: engsys upgrade --project $project_dir"
      fi
    else
      doctor_report warn 'locked revision is not on origin/main yet' \
        'push or merge it before a teammate clones this project; their engsys cannot fetch it'
    fi
  else
    doctor_report fail "locked system revision is missing locally: $locked" \
      "run: git -C $system_root fetch origin"
    failures=$((failures + 1))
  fi

  printf '\n%s\n' "$failures problem(s) to fix"
  [ "$failures" -eq 0 ] || exit 1
}

# 선언한 block 이 파싱되지 않으면 검사는 조용히 0건으로 통과한다. 들여쓰기를 잘못 쓴 계약이
# 그대로 gate 를 지나가는 것을 막기 위해, 선언했는데 내용이 없는 경우를 오류로 본다.
