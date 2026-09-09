#!/bin/sh

# CRLF 로 checkout 된 계약은 값 끝에 CR 을 달고 온다. 그 오류는 원인을 가리키지 않으므로
# 먼저 잡아서 고칠 명령을 알려 준다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0
project="$temporary/project"
mkdir -p "$project"
git -C "$project" init -q
"$system_root/bin/engsys" init --project "$project" --verify true >/dev/null 2>&1

check() { ENGSYS_USE_CHECKOUT=1 "$system_root/bin/engsys" check --project "$project" \
  >"$temporary/out" 2>"$temporary/err"; }

check

# 계약이 CRLF 면 원인과 고칠 명령을 말한다.
awk '{ printf "%s\r\n", $0 }' "$project/.engsys/project.yaml" >"$temporary/crlf"
cp "$temporary/crlf" "$project/.engsys/project.yaml"
if check; then
  printf 'check must refuse a contract with CRLF line endings\n' >&2
  exit 1
fi
grep -Fq 'has CRLF line endings' "$temporary/err"
grep -Fq 'rm --cached -r -q .' "$temporary/err"
tr -d '\r' <"$project/.engsys/project.yaml" >"$temporary/lf"
cp "$temporary/lf" "$project/.engsys/project.yaml"
check

# lock 도 같은 검사를 받는다.
awk '{ printf "%s\r\n", $0 }' "$project/.engsys/lock.yaml" >"$temporary/crlf"
cp "$temporary/crlf" "$project/.engsys/lock.yaml"
if check; then
  printf 'check must refuse a lock with CRLF line endings\n' >&2
  exit 1
fi
grep -Fq 'has CRLF line endings' "$temporary/err"

# 저장소는 .gitattributes 로 LF 를 강제한다. Windows 의 core.autocrlf 와 무관해야 한다.
grep -Fq 'text=auto eol=lf' "$system_root/.gitattributes"

printf 'ok CRLF checkouts are named instead of failing somewhere else\n'
