#!/bin/sh

# venv 의 실행 경로는 OS 마다 다르다. 계약이 platform 변형을 선언하면 사람이 고르지 않고
# engsys 가 고른다. 고르지 못한 변형은 아무 곳에서도 실행되지 않으므로 검사에서 막는다.
set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(CDPATH= cd -- "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$temporary"' 0

project="$temporary/project"
mkdir -p "$project"
git -C "$project" init -q
"$system_root/bin/engsys" init --project "$project" --name platform-fixture \
  --verify 'printf base-verify\n' >/dev/null

contract="$project/.engsys/project.yaml"
engsys() { ENGSYS_USE_CHECKOUT=1 "$system_root/bin/engsys" "$@"; }

# 변형이 없으면 기본 선언을 쓴다.
engsys verify --project "$project" >"$temporary/out" 2>&1
grep -Fq 'commands.verify)' "$temporary/out"
grep -Fq 'base-verify' "$temporary/out"

# 이 platform 의 변형이 있으면 그것이 기본 선언을 대체한다.
platform=$(uname -s | sed 's/Darwin/macos/; s/Linux/linux/; s/^MINGW.*/windows/; s/^MSYS.*/windows/; s/^CYGWIN.*/windows/')
awk -v key="  verify-$platform: 'printf variant-verify\\\\n'" \
  '{ print } /^  verify:/ { print key }' "$contract" >"$temporary/contract"
cp "$temporary/contract" "$contract"
engsys verify --project "$project" >"$temporary/out" 2>&1
grep -Fq "commands.verify-$platform)" "$temporary/out"
grep -Fq 'variant-verify' "$temporary/out"
if grep -Fq 'base-verify' "$temporary/out"; then
  printf 'the platform variant must replace the base command, not run beside it\n' >&2
  exit 1
fi

# 다른 platform 의 변형은 이 머신에서 고르지 않는다.
other=windows
[ "$platform" != windows ] || other=linux
awk -v key="  verify-$other: 'printf other-verify\\\\n'" \
  '{ print } /^  verify:/ { print key }' "$contract" | grep -v "verify-$platform:" >"$temporary/contract"
cp "$temporary/contract" "$contract"
engsys verify --project "$project" >"$temporary/out" 2>&1
grep -Fq 'commands.verify)' "$temporary/out"
if grep -Fq 'other-verify' "$temporary/out"; then
  printf 'a variant for another platform must not run here\n' >&2
  exit 1
fi

# 오타 난 변형은 어느 platform 에서도 실행되지 않으므로 계약 검사가 막는다.
sed "s/verify-$other:/verify-win:/" "$contract" >"$temporary/contract"
cp "$temporary/contract" "$contract"
if engsys check --project "$project" >"$temporary/out" 2>&1; then
  printf 'check must refuse an unknown commands key\n' >&2
  exit 1
fi
grep -Fq 'unknown commands key: verify-win' "$temporary/out"

# 기본 선언이 이 platform 에서 실행되지 않으면 해법을 실패 지점에서 알려 준다.
# verify-windows 라는 답이 표준 안에 있는데 shell 의 127 만 흘리면 아무도 찾지 못한다.
sed "s|^  verify:.*|  verify: './nowhere/poe check'|; /verify-win:/d" "$contract" >"$temporary/contract"
cp "$temporary/contract" "$contract"
if engsys verify --project "$project" >"$temporary/out" 2>&1; then
  printf 'a missing verify command must fail\n' >&2
  exit 1
fi
grep -Fq "declare commands.verify-$platform" "$temporary/out" || {
  printf 'the failure must name the platform variant that would fix it\n' >&2
  cat "$temporary/out" >&2
  exit 1
}

# generated 문서의 재생성 명령도 같은 환경을 쓰므로 같은 방식으로 갈린다.
generated="$temporary/generated"
mkdir -p "$generated/docs/architecture"
git -C "$generated" init -q
"$system_root/bin/engsys" init --project "$generated" --name generated-fixture \
  --verify 'printf base-verify\n' \
  --generated docs/architecture/data-model.md 'printf base-generated\n' >/dev/null

contract="$generated/.engsys/project.yaml"
awk -v key="      command-$platform: 'printf variant-generated\\\\n'" \
  '{ print } /^      command:/ { print key }' "$contract" >"$temporary/contract"
cp "$temporary/contract" "$contract"
engsys verify --project "$generated" >"$temporary/out" 2>&1
grep -Fq 'variant-generated' "$temporary/out"
if grep -Fq 'base-generated' "$temporary/out"; then
  printf 'the platform variant must replace the generated command\n' >&2
  exit 1
fi

# 기본 선언 없이 변형만 둔 record 는 다른 platform 에서 실행할 것이 없다.
grep -v '^      command:' "$contract" >"$temporary/contract"
cp "$temporary/contract" "$contract"
if engsys verify --project "$generated" >"$temporary/out" 2>&1; then
  printf 'a generated record without the base command must fail\n' >&2
  exit 1
fi
grep -Fq 'requires output and command' "$temporary/out"

printf 'platform command tests passed\n'
