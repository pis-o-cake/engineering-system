#!/bin/sh

# 감지는 새 프로젝트가 손으로 적었을 선언만 채운다. 명시한 값이 언제나 이긴다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0

new_project() {
  project="$temporary/$1"
  mkdir -p "$project"
  git -C "$project" init -q
  git -C "$project" config user.name 'Detect Fixture'
  git -C "$project" config user.email 'fixture@example.test'
}
init() { "$system_root/bin/engsys" init --project "$project" "$@" >"$temporary/result" 2>&1; }
verify_line() {
  grep -Fq "  verify: '$1'" "$project/.engsys/project.yaml" || {
    printf 'Expected verify %s\n' "$1" >&2
    cat "$project/.engsys/project.yaml" >&2
    exit 1
  }
}

# 스택마다 native 검증 명령을 찾는다.
new_project make-project
printf 'check:\n\techo ok\n' >"$project/Makefile"
init --detect
verify_line 'make check'
grep -Fq 'detected verify command: make check' "$temporary/result"

new_project poe-project
printf '[tool.poe.tasks]\ncheck = "pytest"\n' >"$project/pyproject.toml"
init --detect
verify_line 'poe check'

new_project pytest-project
printf '[project]\nname = "x"\n' >"$project/pyproject.toml"
init --detect
verify_line 'pytest'

new_project node-project
printf '{ "scripts": { "test": "vitest" } }\n' >"$project/package.json"
init --detect
verify_line 'npm test'

# 찾지 못하면 조용히 넘어가지 않고 --verify 를 요구한다.
new_project empty-project
if init --detect; then
  printf 'Unexpected success without a detectable verify command\n' >&2
  exit 1
fi
grep -Fq 'detection found no native verification command' "$temporary/result"

# 명시한 값이 감지보다 우선한다.
new_project explicit-project
printf 'check:\n\techo ok\n' >"$project/Makefile"
mkdir -p "$project/backend"
init --detect --verify 'make test' --source api=api/
verify_line 'make test'
grep -Fq "    api: 'api/'" "$project/.engsys/project.yaml"
if grep -Fq 'backend:' "$project/.engsys/project.yaml"; then
  printf 'Explicit --source must disable source detection\n' >&2
  exit 1
fi

# 구조가 있는 프로젝트는 정본 경로와 lifecycle 까지 채운다.
new_project full-project
printf 'check:\n\techo ok\n' >"$project/Makefile"
mkdir -p "$project/backend" "$project/frontend" "$project/docs/design" "$project/docs/adr" \
  "$project/docs/architecture"
printf '# Policy\n' >"$project/docs/documentation-policy.md"
printf '# Architecture\n' >"$project/docs/architecture/README.md"
printf '# ADR\n' >"$project/docs/adr/0001-x.md"
init --detect
contract="$project/.engsys/project.yaml"
grep -Fq "    backend: 'backend/'" "$contract"
grep -Fq "    frontend: 'frontend/'" "$contract"
grep -Fq "  policy: 'docs/documentation-policy.md'" "$contract"
grep -Fq "  architecture: 'docs/architecture/README.md'" "$contract"
grep -Fq "      path: 'docs/design'" "$contract"
grep -Fq "      path: 'docs/adr'" "$contract"

# 이미 문서가 있는 경로는 배정하지 않고 그 사실을 알린다.
grep -Fq 'not assigned because documents already exist there' "$temporary/result"
grep -Fq 'docs/adr' "$temporary/result"
if grep -Fq "        type: 'decision-record'" "$contract"; then
  printf 'Untyped existing documents must not be assigned\n' >&2
  exit 1
fi
grep -Fq "        type: 'design-proposal'" "$contract"
python3 "$system_root/tools/validate-contract.py" project "$contract" >/dev/null
"$system_root/bin/engsys" check --project "$project" >/dev/null

# 배정한 경로에 아직 문서가 없어도 검사는 통과한다.
"$system_root/bin/engsys" docs check --project "$project" >"$temporary/result" 2>&1
grep -Fq '0 assigned documents, 0 findings' "$temporary/result"

# --hooks 는 gate 를 쓰고 등록한다. 기존 파일과 설정은 건드리지 않는다.
new_project hooked-project
printf 'check:\n\techo ok\n' >"$project/Makefile"
init --detect --hooks
grep -Fq 'wrote .githooks/pre-push' "$temporary/result"
grep -Fq 'registered core.hooksPath .githooks' "$temporary/result"
[ -x "$project/.githooks/pre-push" ]
[ "$(git -C "$project" config --get core.hooksPath)" = .githooks ]

new_project kept-hook-project
printf 'check:\n\techo ok\n' >"$project/Makefile"
mkdir -p "$project/.githooks"
printf '#!/bin/sh\nexit 0\n' >"$project/.githooks/pre-push"
git -C "$project" config core.hooksPath .husky
init --detect --hooks
grep -Fq 'kept the existing .githooks/pre-push' "$temporary/result"
grep -Fq 'left core.hooksPath as .husky' "$temporary/result"
[ "$(git -C "$project" config --get core.hooksPath)" = .husky ]

# gate 는 launcher 가 없으면 원인을 알리고 push 를 막는다.
new_project gate-project
printf 'check:\n\techo ok\n' >"$project/Makefile"
init --detect --hooks
printf 'refs/heads/x 1111111111111111111111111111111111111111 refs/heads/x 0000000000000000000000000000000000000000\n' \
  >"$temporary/refs"
mkdir -p "$temporary/bin"
for tool in git mktemp rm grep cat sed awk; do
  tool_path=$(command -v "$tool" 2>/dev/null) || continue
  ln -sf "$tool_path" "$temporary/bin/$tool"
done
if ( cd "$project" && PATH="$temporary/bin" /bin/sh .githooks/pre-push <"$temporary/refs" ) >"$temporary/result" 2>&1; then
  printf 'a missing launcher must block the push\n' >&2
  exit 1
fi
grep -Fq 'engsys is not on PATH' "$temporary/result"

printf 'ok init detects declarations and installs the project gate\n'
