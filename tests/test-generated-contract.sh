#!/bin/sh

set -eu
system_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' 0

git -C "$test_dir" init -q
"$system_root/bin/engsys" init --project "$test_dir" --verify 'true' \
  --generated docs/generated.md 'false' >/dev/null
cp "$test_dir/.engsys/project.yaml" "$test_dir/original.yaml"

# Schema-valid mapping order must not remove the native check or hook protection.
python3 - "$test_dir" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
contract = root / '.engsys/project.yaml'
text = contract.read_text().replace(
    "    - output: 'docs/generated.md'\n      command: 'false'",
    "    - command: 'false'\n      output: 'docs/generated.md'",
)
# CRLF 로 저장하면 engsys 가 계약을 읽기 전에 줄바꿈으로 거부한다.
with contract.open('w', newline='\n') as handle:
    handle.write(text)
PY
# 어느 단계가 깨졌는지 이름으로 남긴다. 조용히 종료하면 platform 차이를 좁힐 수 없다.
fail() {
  printf '%s\n' "$1" >&2
  shift
  [ "$#" -eq 0 ] || cat "$@" >&2
  exit 1
}

python3 "$system_root/tools/validate-contract.py" --project-dir "$test_dir"
"$system_root/bin/engsys" sync --project "$test_dir" >"$test_dir/sync.log" 2>&1 \
  || fail 'sync rejected a reordered generated record' "$test_dir/sync.log"
grep -Fxq 'docs/generated.md' "$test_dir/.engsys/generated-paths.txt" \
  || fail 'sync did not record the generated output' "$test_dir/.engsys/generated-paths.txt"
if "$system_root/bin/engsys" verify --project "$test_dir" >"$test_dir/verify.log" 2>&1; then
  fail 'verify skipped a reordered generated command' "$test_dir/verify.log"
fi
grep -Fq 'Running generated-document verification: false' "$test_dir/verify.log" \
  || fail 'verify did not name the generated command it ran' "$test_dir/verify.log"
denied=$(printf '%s' '{"tool_input":{"file_path":"docs/generated.md"}}' \
  | CLAUDE_PROJECT_DIR="$test_dir" sh "$system_root/packages/docs-gov/claude-code/hooks/block-generated-edit.sh")
printf '%s\n' "$denied" | grep -Fq '"permissionDecision": "deny"' \
  || fail "generated output was not denied: [$denied]"

# Exercise record pairing, scalar quoting and unsupported input against the CLI.
python3 - "$system_root" "$test_dir" <<'PY'
from pathlib import Path
import subprocess
import sys

system, root = map(Path, sys.argv[1:])
contract = root / '.engsys/project.yaml'
original = (root / 'original.yaml').read_text()
start = original.index('  generated:')
end = original.index('  lifecycle:')
def write(block):
    # CRLF 로 저장하면 engsys 가 계약을 읽기 전에 줄바꿈으로 거부한다.
    with contract.open('w', newline='\n') as handle:
        handle.write(original[:start] + block + original[end:])
def cli(command):
    # Windows 는 shebang 을 해석하지 않는다. launcher 는 언제나 sh 로 실행한다.
    return subprocess.run(['sh', str(system / 'bin/engsys'), command, '--project', str(root)],
                          text=True, capture_output=True)

write('''  generated:
    - command: "printf checked > first-marker"
      output: 'docs/first.md'
    -
      output: 'docs/second.md'
      command: 'printf ''quoted'' > second-marker'
''')
assert cli('sync').returncode == 0
assert cli('verify').returncode == 0
assert (root / 'first-marker').read_text() == 'checked'
assert (root / 'second-marker').read_text() == 'quoted'
assert (root / '.engsys/generated-paths.txt').read_text().splitlines() == [
    'docs/first.md', 'docs/second.md']

# Indentless YAML sequences must have the same record semantics.
write("  generated:\n  - command: 'true'\n    output: 'docs/generated.md'\n")
assert cli('sync').returncode == 0
assert cli('verify').returncode == 0
previous = (root / '.engsys/generated-paths.txt').read_bytes()
invalid = [
    "  generated:\n    - output: 'docs/generated.md'\n",
    "  generated:\n    - command: 'true'\n",
    "  generated:\n    - output: 'docs/generated.md'\n      command: ''\n",
    "  generated:\n    - output: 'docs/generated.md'\n      command: 'true'\n      command: 'false'\n",
    "  generated:\n    - output: 'docs/generated.md'\n      command: |\n        false\n",
    "  generated: [{output: docs/generated.md, command: false}]\n",
    "  generated:\n",
]
for block in invalid:
    write(block)
    for command in ('sync', 'check', 'verify'):
        result = cli(command)
        assert result.returncode != 0, (command, block, result.stdout)
    assert (root / '.engsys/generated-paths.txt').read_bytes() == previous

write("  generated: []\n")
assert cli('sync').returncode == 0
assert cli('verify').returncode == 0
assert (root / '.engsys/generated-paths.txt').read_bytes() == b''
print('ok generated records retain checks and reject unsupported input')
PY
