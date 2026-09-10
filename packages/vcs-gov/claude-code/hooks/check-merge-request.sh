#!/bin/sh
# Claude Code PreToolUse hook. gh 로 merge request 를 만들거나 고칠 때 본문이 계약을 지키는지
# 판정한다. skill 은 지시문이라 무시할 수 있다. 이 gate 는 세션이 무엇을 읽었는지와 무관하다.
#
# 판정하려면 본문을 읽을 수 있어야 한다. 그래서 --body-file 을 요구하고 inline --body 는 막는다.

set -eu

deny() {
  # JSON 문자열로 넣으려면 제어문자와 따옴표를 이스케이프해야 한다.
  reason=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{ printf "%s\\n", $0 }')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
  exit 0
}

payload=$(cat)
# 값싼 선별이다. 실제 판정은 명령 자리에 있는 gh 만 본다 — heredoc 안의 산문에 같은 글자가
# 있다고 해서 그것을 실행하는 것은 아니다.
case "$payload" in
  *'gh pr create'*|*'gh pr edit'*) ;;
  *) exit 0 ;;
esac

cwd=$(printf '%s' "$payload" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
project_dir=${CLAUDE_PROJECT_DIR:-}
if [ -n "$cwd" ] && cdup=$(git -C "$cwd" rev-parse --show-cdup 2>/dev/null); then
  project_dir=$(CDPATH= cd -- "$cwd/${cdup:-.}" && pwd -P)
fi
[ -n "$project_dir" ] || exit 0
[ -f "$project_dir/.engsys/project.yaml" ] || exit 0
grep -q '^vcs:' "$project_dir/.engsys/project.yaml" || exit 0

# 명령 문자열은 JSON 안에서 이스케이프돼 있다. python3 가 있으면 그것으로 읽는다.
if command -v python3 >/dev/null 2>&1; then
  parsed=$(printf '%s' "$payload" | python3 -c '
import json, os, re, shlex, sys

try:
    command = json.load(sys.stdin).get("tool_input", {}).get("command", "")
except Exception:
    print("PARSE\tfailed")
    raise SystemExit(0)

# heredoc 본문은 실행되는 명령이 아니라 데이터다. 이 gate 를 설명하는 커밋 메시지가
# 자기 자신에게 걸린 적이 있다. 판정 전에 걷어낸다.
def strip_heredocs(text):
    lines = text.split("\n")
    kept = []
    index = 0
    while index < len(lines):
        line = lines[index]
        kept.append(line)
        index += 1
        for opener in re.finditer(r"<<-?\s*([\"\x27]?)([A-Za-z_][A-Za-z0-9_]*)\1", line):
            word = opener.group(2)
            while index < len(lines) and lines[index].strip() != word:
                index += 1
            index += 1
    return "\n".join(kept)

command = strip_heredocs(command)

# 줄 처음이나 ; && || | 뒤에 온 gh 만 실행되는 명령이다. 산문 속의 같은 글자는 아니다.
match = re.search(r"(?:\A|[;&|]\s*|\n\s*)gh\s+pr\s+(create|edit)\b", command)
if not match:
    raise SystemExit(0)

try:
    words = shlex.split(command[match.end():])
except Exception:
    print("PARSE\tfailed")
    raise SystemExit(0)

# shlex 는 변수를 펴지 않는다. 같은 명령에서 세운 변수는 hook 프로세스의 환경에도 없으므로
# 명령 안의 대입을 먼저 모은다. 값이 명령 치환이면 알 수 없고, 그때는 통과시키지 않는다.
ASSIGNMENT = re.compile(r"\A([A-Za-z_][A-Za-z0-9_]*)=(.*)\Z", re.S)
REFERENCE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)")

def resolve(value, known):
    if value.startswith("~"):
        value = os.path.expanduser(value)
    if "$" not in value:
        return value
    def replace(hit):
        name = hit.group(1) or hit.group(2)
        if name in known:
            return known[name]
        return os.environ.get(name, hit.group(0))
    return REFERENCE.sub(replace, value)

assignments = {}
try:
    for word in shlex.split(strip_heredocs(command)):
        found = ASSIGNMENT.match(word)
        if found:
            assignments[found.group(1)] = resolve(found.group(2), assignments)
except Exception:
    assignments = {}

print("ACTION\t" + match.group(1))
for word in words:
    if word in (";", "&&", "||", "|"):
        break
    if word in ("--body-file", "--body", "--title"):
        position = words.index(word)
        value = words[position + 1] if position + 1 < len(words) else ""
        print(word + "\t" + resolve(value, assignments))
' 2>/dev/null) || parsed='PARSE	failed'
else
  # python3 가 없으면 같은 자리 규칙을 grep 으로 본다. 읽지 못하면 통과시키지 않는다.
  command_text=$(printf '%s' "$payload" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p')
  if printf '%s' "$command_text" | grep -Eq '(^|[;&|]|\\n)[[:space:]]*gh[[:space:]]+pr[[:space:]]+(create|edit)'; then
    action_word=$(printf '%s' "$command_text" \
      | sed -n 's/.*gh[[:space:]][[:space:]]*pr[[:space:]][[:space:]]*\(create\|edit\).*/\1/p')
    parsed="ACTION	${action_word:-create}"
    case "$command_text" in
      *--body-file*)
        body_token=$(printf '%s' "$command_text" \
          | sed -n 's/.*--body-file[ =][ ]*\([^ "\\]*\).*/\1/p')
        parsed="$parsed
--body-file	$body_token"
        ;;
      *--body*) parsed="$parsed
--body	inline" ;;
    esac
  else
    exit 0
  fi
fi

case "$parsed" in
  *'PARSE	failed'*)
    deny 'engsys: could not read this gh command, so the merge request body was not checked. Write the body to a file and pass --body-file <path>.' ;;
esac

field() { printf '%s' "$parsed" | awk -F'\t' -v k="$1" '$1 == k { print $2; exit }'; }
action=$(field ACTION)
[ -n "$action" ] || exit 0
body_file=$(field --body-file)
title=$(field --title)

case "$parsed" in
  *'--body	'*)
    deny 'engsys: pass the merge request body as --body-file <path>, not inline --body. The gate can only judge a body it can read.' ;;
esac

if [ -z "$body_file" ]; then
  [ "$action" = edit ] && exit 0
  deny 'engsys: gh pr create needs --body-file <path>. The merge request body follows packages/vcs-gov/commit-contract.yaml, and the gate must read it before the request is opened.'
fi

case "$body_file" in /*) ;; *) body_file="$cwd/$body_file" ;; esac
[ -f "$body_file" ] || deny "engsys: the body file does not exist: $body_file"

# 이 hook 을 부른 engsys 와 판정하는 engsys 는 같아야 한다. PATH 를 먼저 믿으면 개발자마다
# 다른 checkout 이 답할 수 있다.
if [ -n "${ENGSYS_SYSTEM_ROOT:-}" ] && [ -x "$ENGSYS_SYSTEM_ROOT/bin/engsys" ]; then
  launcher="$ENGSYS_SYSTEM_ROOT/bin/engsys"
else
  launcher=$(command -v engsys 2>/dev/null || true)
fi
[ -n "$launcher" ] || deny 'engsys: engsys is not on PATH, so the merge request body was not checked. Run install.sh in the system checkout.'

set -- vcs check-merge-request "$body_file" --project "$project_dir"
[ -z "$title" ] || set -- "$@" --title "$title"
if ! output=$("$launcher" "$@" 2>&1); then
  deny "$output"
fi
exit 0
