#!/bin/sh

# install 은 개발자 자신의 shell profile 과 clone 의 hook 경로만 바꾼다. 두 번 돌려도 같다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0

clone="$temporary/clone"
# Windows 는 임시 디렉터리 사이의 hardlink 를 만들지 못한다.
git clone -q --local --no-hardlinks "$system_root" "$clone"
git -C "$clone" config user.name 'Install Fixture'
git -C "$clone" config user.email 'fixture@example.test'
# clone 은 commit 만 갖는다. 검사 대상은 working tree 의 install 과 launcher 다.
cp "$system_root/install.sh" "$clone/install.sh"
cp "$system_root/bin/engsys" "$clone/bin/engsys"
cp "$system_root/lib/"*.sh "$clone/lib/"
profile="$temporary/profile"

install() { (cd "$clone" && ./install.sh --profile-file "$profile" "$@") >"$temporary/result" 2>&1 || true; }

# --print 는 아무것도 쓰지 않는다.
install --print
grep -Fq "$clone/bin/engsys shellenv" "$temporary/result"
[ ! -e "$profile" ]

# 첫 실행이 profile 줄과 hook 경로를 만든다.
install
grep -Fq 'added the activation line' "$temporary/result"
grep -Fq 'registered the push gate' "$temporary/result"
grep -Fq "eval \"\$($clone/bin/engsys shellenv)\"" "$profile"
[ "$(git -C "$clone" config --get core.hooksPath)" = .githooks ]

# 두 번째 실행은 줄을 늘리지 않는다.
before=$(wc -l <"$profile")
install
grep -Fq 'already activates this checkout' "$temporary/result"
grep -Fq 'already registered' "$temporary/result"
[ "$(wc -l <"$profile")" = "$before" ]

# 다른 checkout 을 가리키는 줄이 있으면 덮지 않고 알린다.
other="$temporary/other-profile"
printf 'eval "$(/somewhere/else/bin/engsys shellenv)"\n' >"$other"
(cd "$clone" && ./install.sh --profile-file "$other") >"$temporary/result" 2>&1 || true
grep -Fq 'activates a different checkout' "$temporary/result"
[ "$(grep -c 'bin/engsys shellenv' "$other")" = 1 ]

# 활성화 뒤의 상태를 doctor 로 보고한다.
install
grep -Fq 'Engineering System:' "$temporary/result"
grep -Fq 'engsys on PATH' "$temporary/result"

# 시스템 clone 밖에서는 실행하지 않는다.
mkdir -p "$temporary/elsewhere"
cp "$clone/install.sh" "$temporary/elsewhere/install.sh"
if (cd "$temporary/elsewhere" && ./install.sh --profile-file "$profile") >"$temporary/result" 2>&1; then
  printf 'Unexpected success outside a system clone\n' >&2
  exit 1
fi
grep -Fq 'run this script from a clone' "$temporary/result"

printf 'ok install activates one developer without touching a project\n'
