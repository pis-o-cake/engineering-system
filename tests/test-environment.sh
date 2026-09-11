#!/bin/sh

# 프로젝트 개발 환경은 표준이 준비할 수 없다. 프로젝트가 진단·준비 명령을 선언하고 표준은
# 실행과 판정만 한다. 이 fixture 는 marker 파일 하나로 환경을 흉내 내므로 Python·Node 같은
# 외부 런타임이 없어도 돈다. 실제 프로젝트의 준비와 test 실행은 별도 통합 검증의 몫이다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0

engsys() { ENGSYS_USE_CHECKOUT=1 "$system_root/bin/engsys" "$@"; }
out="$temporary/out"

# 환경 미준비로 검사를 못 한 것은 검사에 떨어진 것과 다르다. 두 상태를 이 코드로 가른다.
environment_exit=3

fail() { printf '%s\n' "$1" >&2; exit 1; }

run() {
  expected=$1
  shift
  actual=0
  "$@" >"$out" 2>&1 || actual=$?
  [ "$actual" = "$expected" ] || {
    cat "$out" >&2
    fail "expected exit $expected, got $actual: $*"
  }
}

project="$temporary/project"
mkdir -p "$project"
git -C "$project" init -q
# 환경이 있어야만 통과하는 native 검사다. 실제 프로젝트의 venv 와 같은 관계다.
engsys init --project "$project" --name environment-fixture \
  --verify 'test -f .ready && printf native-verify\n' \
  --environment-check 'test -f .ready' \
  --environment-setup 'touch .ready && printf prepared\n' >/dev/null

contract="$project/.engsys/project.yaml"
grep -Fq "  environment-check: 'test -f .ready'" "$contract" \
  || fail 'init must write the declared environment-check'
grep -Fq '  environment-setup:' "$contract" \
  || fail 'init must write the declared environment-setup'

# 선언한 두 키는 계약 검사를 통과해야 한다.
run 0 engsys check --project "$project"

# 미준비 상태: verify 는 프로젝트의 native 검사를 시작하지도 않고 전용 코드로 끝난다.
run "$environment_exit" engsys verify --project "$project"
grep -Fq 'Project environment is not ready' "$out" \
  || fail 'verify must name the environment as the reason'
grep -Fq 'engsys env prepare' "$out" \
  || fail 'verify must say how to prepare the environment'
if grep -Fq 'native-verify' "$out"; then
  fail 'verify must not run the project checks while the environment is not ready'
fi
[ ! -f "$project/.ready" ] || fail 'verify must never run the environment setup command'

# 진단은 같은 판정을 같은 코드로 답한다.
run "$environment_exit" engsys env status --project "$project"
grep -Fq 'Project environment is not ready' "$out" || fail 'env status must report the state'
[ ! -f "$project/.ready" ] || fail 'env status must not prepare anything'

# 준비는 사람이 이 명령을 부른 흐름에서만 돈다. --dry-run 은 무엇을 실행할지만 보여 준다.
run 0 engsys env prepare --project "$project" --dry-run
grep -Fq 'Would run (commands.environment-setup)' "$out" || fail 'dry-run must show the command'
[ ! -f "$project/.ready" ] || fail '--dry-run must change nothing'

run 0 engsys env prepare --project "$project"
[ -f "$project/.ready" ] || fail 'env prepare must run the declared setup command'
grep -Fq 'Ready to run' "$out" || fail 'env prepare must re-check the environment afterwards'

run 0 engsys env status --project "$project"
run 0 engsys verify --project "$project"
grep -Fq 'Project environment is ready (commands.environment-check)' "$out" \
  || fail 'verify must report the environment it judged'
grep -Fq 'native-verify' "$out" || fail 'verify must run the project checks once the environment is ready'

# 준비 실패는 미준비와도 검증 실패와도 다른 사실이다. 준비 명령의 코드를 그대로 돌려준다.
broken="$temporary/broken"
sed "s|  environment-setup: .*|  environment-setup: 'printf no-package-manager\\\\n >\&2; exit 9'|" \
  "$contract" >"$broken"
cp "$broken" "$contract"
rm -f "$project/.ready"
run 9 engsys env prepare --project "$project"
grep -Fq 'Project environment preparation failed' "$out" || fail 'a failed preparation must say so'
grep -Fq 'no-package-manager' "$out" || fail "the project command's own output must survive"

# 검증 실패는 환경 메시지를 쓰지 않는다. 환경은 준비됐고 프로젝트 검사가 떨어진 것이다.
touch "$project/.ready"
failing="$temporary/failing"
sed "s|  verify: .*|  verify: 'printf broken-native\\\\n >\&2; exit 1'|" "$contract" >"$failing"
cp "$failing" "$contract"
run 1 engsys verify --project "$project"
grep -Fq 'broken-native' "$out" || fail 'a failing project check must show its own output'
if grep -Fq 'Project environment is not ready' "$out"; then
  fail 'a failing project check must not be reported as a missing environment'
fi

# doctor 는 표준의 설치·연결 문제와 프로젝트 환경을 같은 칸에 세지 않는다.
rm -f "$project/.ready"
run "$environment_exit" engsys doctor --project "$project"
grep -Fq '0 problem(s) to fix' "$out" || fail 'doctor must not count the environment as its own problem'
grep -Fq '1 environment step(s)' "$out" || fail 'doctor must report the environment step separately'
grep -Eq '^ENV ' "$out" || fail 'doctor must mark the environment line as its own kind'

# platform 변형은 verify 와 같은 방식으로 고른다.
platform=$(uname -s | sed 's/Darwin/macos/; s/Linux/linux/; s/^MINGW.*/windows/; s/^MSYS.*/windows/; s/^CYGWIN.*/windows/')
variant="$temporary/variant"
awk -v key="  environment-check-$platform: 'test -f .ready-variant'" \
  '{ print } /^  environment-check:/ { print key }' "$contract" >"$variant"
cp "$variant" "$contract"
run "$environment_exit" engsys env status --project "$project"
grep -Fq "commands.environment-check-$platform" "$out" \
  || fail 'the platform variant must replace the base declaration'
touch "$project/.ready-variant"
run 0 engsys env status --project "$project"

# 오타 난 변형은 어느 platform 에서도 실행되지 않으므로 계약 검사가 막는다.
typo="$temporary/typo"
sed "s/environment-check-$platform:/environment-check-win:/" "$contract" >"$typo"
cp "$typo" "$contract"
run 1 engsys check --project "$project"
grep -Fq 'unknown commands key: environment-check-win' "$out" \
  || fail 'check must refuse an unknown environment variant'

# 선언이 없는 기존 계약은 이 기능이 생기기 전과 똑같이 동작한다.
legacy="$temporary/legacy"
mkdir -p "$legacy"
git -C "$legacy" init -q
engsys init --project "$legacy" --name legacy-fixture --verify 'printf legacy-verify\n' >/dev/null
grep -q 'environment-' "$legacy/.engsys/project.yaml" \
  && fail 'init must not declare environment commands that were not asked for'
run 0 engsys check --project "$legacy"
run 0 engsys verify --project "$legacy"
grep -Fq 'legacy-verify' "$out" || fail 'a contract without environment commands must still verify'
if grep -Fq 'Checking project environment' "$out"; then
  fail 'engsys must not invent an environment check for a contract that declares none'
fi
run 0 engsys env status --project "$legacy"
grep -Fq 'not declared' "$out" || fail 'env status must say the project declared nothing'
run 1 engsys env prepare --project "$legacy"
grep -Fq 'no commands.environment-setup' "$out" \
  || fail 'env prepare must refuse when the project declared no setup command'

printf 'ok environment declarations separate a missing dev environment from a failed check\n'
