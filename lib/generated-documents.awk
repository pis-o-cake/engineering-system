# Read documentation.generated as records, rather than matching individual lines.
# This is the project's dependency-free reader. Unsupported syntax must fail closed.

function fail(message) {
    print "engsys: generated documentation, line " NR ": " message > "/dev/stderr"
    failed = 1
    exit 1
}

function trim(value) {
    sub(/^[ \t]+/, "", value)
    sub(/[ \t]+$/, "", value)
    return value
}

function scalar(value,    quote, result, i, character, tail) {
    value = trim(value)
    quote = substr(value, 1, 1)
    if (quote == sprintf("%c", 39) || quote == "\"") {
        result = ""
        for (i = 2; i <= length(value); i++) {
            character = substr(value, i, 1)
            if (quote == "\"" && character == "\\")
                fail("double-quoted escapes are unsupported; use a single-quoted scalar")
            if (character == quote) {
                if (quote != "\"" && substr(value, i + 1, 1) == quote) {
                    result = result quote
                    i++
                    continue
                }
                tail = trim(substr(value, i + 1))
                if (tail != "" && tail !~ /^#/) fail("content after quoted scalar")
                if (result == "") fail("output and command must not be empty")
                return result
            }
            result = result character
        }
        fail("unterminated quoted scalar")
    }
    sub(/[ \t]+#.*/, "", value)
    value = trim(value)
    if (value == "" || value ~ /^[>|\[\]{&*!]/ || value ~ /:[ \t]/ ||
        value ~ /^(true|false|null|~|-?[0-9]+)$/)
        fail("expected a nonempty string; use a single-quoted scalar")
    return value
}

function field(text,    key, value) {
    if (text !~ /^(output|command|command-(macos|linux|windows)):[ \t]/)
        fail("expected output, command, or command-<macos|linux|windows> scalar")
    key = text
    sub(/:.*/, "", key)
    value = text
    sub(/^[^:]+:[ \t]*/, "", value)
    if (key in record) fail("duplicate " key)
    record[key] = scalar(value)
}

function emit(    key) {
    if (!entry) return
    if (!("output" in record) || !("command" in record))
        fail("each generated record requires output and command")
    # platform 변형은 기본 선언을 대체한다. 기본 선언은 어느 record 에나 있어야 한다.
    if (requested == "command" && ("command-" platform) in record)
        print record["command-" platform]
    else
        print record[requested]
    for (key in record) delete record[key]
    entry = 0
}

function finish() {
    if (generated && !entry && !count) fail("empty generated block; use generated: []")
    emit()
    generated = 0
}

{
    sub(/\r$/, "")
    if ($0 ~ /^[ \t]*(#|$)/) next
    if ($0 ~ /^ *\t/) fail("tab indentation is unsupported")
    match($0, /^ */)
    indent = RLENGTH
    content = trim(substr($0, indent + 1))

    if (indent == 0) {
        finish()
        document = 0
        if (content ~ /^documentation:/) {
            if (seen_document++) fail("duplicate documentation mapping")
            value = content
            sub(/^documentation:[ \t]*/, "", value)
            sub(/[ \t]+#.*/, "", value)
            if (value != "" && value != "{}" && value !~ /^#/)
                fail("documentation must be a block mapping")
            document = 1
            child_indent = 0
        }
        next
    }
    if (!document) next
    if (!child_indent) child_indent = indent
    if (indent < child_indent) fail("inconsistent documentation indentation")

    # An indentless sequence may share its parent's indentation.
    if (indent == child_indent && content !~ /^-([ \t]|$)/) {
        finish()
        if (content !~ /^[A-Za-z0-9_-]+:/) fail("unsupported documentation key")
        if (content ~ /^generated:/) {
            if (seen_generated++) fail("duplicate generated mapping")
            value = content
            sub(/^generated:[ \t]*/, "", value)
            sub(/[ \t]+#.*/, "", value)
            if (value == "[]") next
            if (value != "" && value !~ /^#/) fail("generated must be a block sequence or []")
            generated = 1
            sequence_indent = -1
            count = 0
        }
        next
    }
    if (!generated) next
    if (sequence_indent < 0) sequence_indent = indent
    if (indent == sequence_indent && content ~ /^-([ \t]|$)/) {
        emit()
        entry = 1
        count++
        sub(/^-[ \t]*/, "", content)
        if (content != "") field(content)
    } else if (entry && indent == sequence_indent + 2) {
        field(content)
    } else {
        fail("unsupported generated record indentation or syntax")
    }
}

END {
    if (!failed) finish()
}
