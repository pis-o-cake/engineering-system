#!/bin/sh

# 프로젝트가 복사한 hook 은 그 프로젝트가 소유한다. 표준은 덮어쓰지 않고 차이만 알린다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0
project="$temporary/project"
mkdir -p "$project"
git -C "$project" init -q

hooks() { "$system_root/bin/engsys" hooks "$@" --project "$project" \
  >"$temporary/out" 2>"$temporary/err"; }
expect() {
  grep -Fq "$1" "$temporary/out" || {
    printf 'Expected %s\n' "$1" >&2; cat "$temporary/out" "$temporary/err" >&2; exit 1
  }
}

# 계약만 만들고 hook 은 설치하지 않은 상태.
"$system_root/bin/engsys" init --project "$project" --verify true >/dev/null 2>&1
if hooks status; then
  printf 'status must report a missing hook\n' >&2; exit 1
fi
expect 'missing  commit-msg'
expect 'missing  pre-push'

# update 가 설치하고 기준선을 기록한다. core.hooksPath 는 commit 되지 않으므로 여기서 세운다.
[ -z "$(git -C "$project" config --get core.hooksPath 2>/dev/null || true)" ]
hooks update
expect 'wrote    commit-msg'
[ -x "$project/.githooks/pre-push" ]
grep -q '^commit-msg	' "$project/.engsys/hooks.txt"
[ "$(git -C "$project" config --get core.hooksPath)" = .githooks ] || {
  printf 'hooks update must register core.hooksPath; hook files alone do not run\n' >&2
  exit 1
}
hooks status
expect '현재 template과 같다'

# 사본을 고치면 갱신이 그 수정을 지운다고 알린다. 조용히 덮지 않는다.
installed_before=$(git -C "$project" hash-object -- "$project/.githooks/pre-push")
printf '\n# 이 프로젝트만의 검사\n' >>"$project/.githooks/pre-push"
if hooks status; then
  printf 'an edited copy must not report as current\n' >&2; exit 1
fi
expect 'modified pre-push'
grep -Fq 'engsys hooks update --force' "$temporary/out"
grep -Fq 'engsys hooks update --adopt' "$temporary/out"

# --force 는 프로젝트의 수정을 버린다.
hooks update --force
expect 'replaced pre-push'
[ "$(git -C "$project" hash-object -- "$project/.githooks/pre-push")" = "$installed_before" ]

# --adopt 는 사본을 유지하고 현재 template 을 확인한 것으로 기록한다.
printf '\n# 이 프로젝트만의 검사\n' >>"$project/.githooks/pre-push"
edited=$(git -C "$project" hash-object -- "$project/.githooks/pre-push")
hooks update --adopt
expect 'adopted  pre-push'
[ "$(git -C "$project" hash-object -- "$project/.githooks/pre-push")" = "$edited" ]
hooks status
expect '프로젝트가 소유한 사본이다'

# 확인한 뒤 template 이 다시 바뀌면 알린다. 기록의 template 해시만 옮겨 그 상황을 만든다.
python3 - "$project/.engsys/hooks.txt" <<'PY'
import sys
path = sys.argv[1]
lines = []
for line in open(path, encoding="utf-8"):
    name, _recorded_template, recorded_installed = line.rstrip("\n").split("\t")
    lines.append("%s\t%s\t%s\n" % (name, "0" * 40, recorded_installed))
open(path, "w").writelines(lines)
PY
if hooks status; then
  printf 'a template change after adoption must be reported\n' >&2; exit 1
fi
expect 'modified pre-push'

# 기준 기록이 없으면 갈라진 이유를 모른다. 프로젝트가 고쳤다고 단정하지 않는다.
rm -f "$project/.engsys/hooks.txt"
if hooks status; then
  printf 'a copy without a baseline must not report as current\n' >&2; exit 1
fi
expect 'unrecorded pre-push'
grep -Fq 'engsys는 모른다' "$temporary/out"
if grep -Fq 'modified pre-push' "$temporary/out"; then
  printf 'engsys must not claim the project edited a copy it has no record of\n' >&2; exit 1
fi
PATH="$system_root/bin:$PATH" "$system_root/bin/engsys" doctor --project "$project" \
  >"$temporary/out" 2>&1 || true
grep -Fq 'differs from the template with no baseline' "$temporary/out"

# --adopt 는 그 사본을 그대로 두고 기준선을 다시 세운다.
hooks update --adopt
expect 'adopted  pre-push'
hooks status
expect '프로젝트가 소유한 사본이다'

# doctor 검사를 위해 template 이 바뀐 상황으로 되돌린다.
python3 - "$project/.engsys/hooks.txt" <<'PY'
import sys
path = sys.argv[1]
lines = []
for line in open(path, encoding="utf-8"):
    name, _recorded_template, recorded_installed = line.rstrip("\n").split("\t")
    lines.append("%s\t%s\t%s\n" % (name, "0" * 40, recorded_installed))
open(path, "w").writelines(lines)
PY

# doctor 도 같은 상태를 보고한다.
PATH="$system_root/bin:$PATH" "$system_root/bin/engsys" doctor --project "$project" \
  >"$temporary/out" 2>&1 || true
grep -Fq 'project hook differs from the template' "$temporary/out"

printf 'ok hook copies are diagnosed and never overwritten silently\n'
