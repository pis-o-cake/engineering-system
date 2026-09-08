#!/bin/sh

# doctor 는 활성화와 계약 상태를 진단한다. 고칠 수 있는 문제만 실패로 센다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' 0
project="$temporary/project"
mkdir -p "$project"
git -C "$project" init -q
git -C "$project" config user.name 'Doctor Fixture'
git -C "$project" config user.email 'fixture@example.test'

# 활성화된 개발자의 PATH 를 흉내낸다. 그러지 않으면 PATH 검사가 항상 실패한다.
doctor() { PATH="$system_root/bin:$PATH" "$system_root/bin/engsys" doctor --project "$project"; }
run() { doctor >"$temporary/result" 2>&1; }
expect_fail() {
  if run; then
    printf 'Unexpected doctor success: %s\n' "$1" >&2
    cat "$temporary/result" >&2
    exit 1
  fi
  grep -Fq "$2" "$temporary/result" || {
    printf 'Missing expected report for %s: %s\n' "$1" "$2" >&2
    cat "$temporary/result" >&2
    exit 1
  }
}

# 채택하지 않은 프로젝트는 실패가 아니라 다음 명령을 알려준다.
run
grep -Fq 'project has not adopted Engineering System' "$temporary/result"
grep -Fq 'engsys init --verify' "$temporary/result"
grep -Fq '0 problem(s) to fix' "$temporary/result"

# 계약이 없는 프로젝트에서 다른 명령을 먼저 부르면 doctor 와 init 으로 안내한다.
for command in check sync verify; do
  if "$system_root/bin/engsys" "$command" --project "$project" >"$temporary/result" 2>&1; then
    printf 'Unexpected success for %s without a contract\n' "$command" >&2
    exit 1
  fi
  grep -Fq 'no Engineering System contract' "$temporary/result" || {
    printf '%s must name the missing contract\n' "$command" >&2
    cat "$temporary/result" >&2
    exit 1
  }
  grep -Fq 'engsys init' "$temporary/result" || {
    printf '%s must name the command that adopts the standard\n' "$command" >&2
    exit 1
  }
done

"$system_root/bin/engsys" init --project "$project" --verify true >/dev/null 2>&1
run
grep -Fq 'project contract and lock pass engsys check' "$temporary/result"
grep -Fq 'profile baseline exists in this system checkout' "$temporary/result"
grep -Fq 'locked system revision is available' "$temporary/result"

# 알 수 없는 profile 과 없는 revision 은 팀원의 clone 에서 실제로 막히는 상태다.
cp "$project/.engsys/project.yaml" "$temporary/contract"
sed 's/^  profile: .*/  profile: '"'"'nonexistent'"'"'/' "$temporary/contract" >"$project/.engsys/project.yaml"
expect_fail 'unknown profile' 'profile is unknown in this system checkout: nonexistent'
cp "$temporary/contract" "$project/.engsys/project.yaml"

cp "$project/.engsys/lock.yaml" "$temporary/lock"
sed "s/^  revision: .*/  revision: '0000000000000000000000000000000000000000'/" "$temporary/lock" \
  >"$project/.engsys/lock.yaml"
expect_fail 'missing revision' 'locked system revision is missing locally'
cp "$temporary/lock" "$project/.engsys/lock.yaml"

# 계약이 깨지면 check 로 안내한다.
printf 'unknown-key: 1\n' >>"$project/.engsys/project.yaml"
expect_fail 'broken contract' 'does not pass engsys check'
cp "$temporary/contract" "$project/.engsys/project.yaml"
run

printf 'ok doctor reports activation and contract state\n'
