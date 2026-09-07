"""Engineering System이 읽고 쓰는 제한된 YAML subset loader.

이 레포는 프로젝트에 dependency를 설치하지 않는다는 제약 때문에 PyYAML을 쓰지 않는다.
대신 `bin/engsys`가 생성하고 소비하는 문법만 지원하고, 그 밖의 문법을 만나면 조용히
넘기지 않고 예외를 던진다. 검증 도구가 읽지 못한 내용을 통과시키면 schema 검사 자체가
무의미해지기 때문이다.

지원 범위:
    - 2칸 들여쓰기 mapping과 sequence
    - single-quoted scalar (`''` escape), 정수, boolean, null
    - inline `{}`, `[]`, `[a, b]`
    - 전체 줄 주석(`#`)과 빈 줄

Example:
    >>> load_text("system:\\n  profile: 'baseline'\\n")
    {'system': {'profile': 'baseline'}}
"""

import re

KEY_PATTERN = re.compile(r"^([A-Za-z0-9_.$-]+):(?:[ \t]+(.*))?$")
INTEGER_PATTERN = re.compile(r"^-?\d+$")


class YamlSubsetError(Exception):
    """지원하지 않는 문법이나 구조를 만났을 때 발생한다."""


def load(path):
    """파일을 읽어 Python 자료구조로 변환한다.

    Args:
        path: 읽을 YAML 파일 경로.

    Returns:
        최상위 mapping에 해당하는 dict. 빈 파일이면 빈 dict.

    Raises:
        YamlSubsetError: 지원하지 않는 문법을 만난 경우.
    """
    with open(path, "r", encoding="utf-8") as handle:
        try:
            return load_text(handle.read())
        except YamlSubsetError as error:
            raise YamlSubsetError("%s: %s" % (path, error))


def load_text(text):
    """문자열을 Python 자료구조로 변환한다."""
    lines = _significant_lines(text)
    if not lines:
        return {}
    if lines[0][1] != 0:
        raise YamlSubsetError("line %d: document must start at column 0" % lines[0][0])
    value, index = _parse_block(lines, 0, 0)
    if index != len(lines):
        raise YamlSubsetError("line %d: unexpected content" % lines[index][0])
    return value


def _significant_lines(text):
    lines = []
    for number, raw in enumerate(text.splitlines(), 1):
        stripped = raw.rstrip()
        if not stripped.strip() or stripped.lstrip().startswith("#"):
            continue
        indent = len(stripped) - len(stripped.lstrip(" "))
        if "\t" in stripped[:indent]:
            raise YamlSubsetError("line %d: tab indentation is not supported" % number)
        lines.append((number, indent, stripped[indent:]))
    return lines


def _parse_block(lines, index, indent):
    _, _, content = lines[index]
    if _is_sequence_entry(content):
        return _parse_sequence(lines, index, indent)
    return _parse_mapping(lines, index, indent)


def _is_sequence_entry(content):
    return content == "-" or content.startswith("- ")


def _parse_mapping(lines, index, indent):
    mapping = {}
    while index < len(lines):
        number, line_indent, content = lines[index]
        if line_indent < indent:
            break
        if line_indent > indent:
            raise YamlSubsetError("line %d: unexpected indentation" % number)
        match = KEY_PATTERN.match(content)
        if not match:
            raise YamlSubsetError("line %d: expected 'key: value'" % number)
        key = match.group(1)
        rest = match.group(2)
        if key in mapping:
            raise YamlSubsetError("line %d: duplicate key '%s'" % (number, key))
        index += 1
        if rest:
            mapping[key] = _parse_scalar(rest, number)
            continue
        mapping[key] = None
        if index >= len(lines):
            continue
        next_number, next_indent, next_content = lines[index]
        if next_indent > indent:
            mapping[key], index = _parse_block(lines, index, next_indent)
        elif next_indent == indent and _is_sequence_entry(next_content):
            mapping[key], index = _parse_sequence(lines, index, indent)
        elif next_indent == indent:
            continue
        else:
            _ = next_number
    return mapping, index


def _parse_sequence(lines, index, indent):
    items = []
    while index < len(lines):
        number, line_indent, content = lines[index]
        if line_indent < indent:
            break
        if line_indent > indent:
            raise YamlSubsetError("line %d: unexpected indentation" % number)
        if not _is_sequence_entry(content):
            break
        inline = content[2:].strip() if content.startswith("- ") else ""
        entry_lines = []
        if inline:
            entry_lines.append((number, indent + 2, inline))
        index += 1
        while index < len(lines) and lines[index][1] > indent:
            entry_lines.append(lines[index])
            index += 1
        if not entry_lines:
            raise YamlSubsetError("line %d: empty sequence entry" % number)
        items.append(_parse_sequence_entry(entry_lines, number))
    return items, index


def _parse_sequence_entry(entry_lines, number):
    if len(entry_lines) == 1 and not KEY_PATTERN.match(entry_lines[0][2]):
        return _parse_scalar(entry_lines[0][2], number)
    value, consumed = _parse_block(entry_lines, 0, entry_lines[0][1])
    if consumed != len(entry_lines):
        raise YamlSubsetError("line %d: unexpected content in sequence entry" % number)
    return value


def _parse_scalar(text, number):
    text = text.strip()
    if len(text) >= 2 and text.startswith("'") and text.endswith("'"):
        return text[1:-1].replace("''", "'")
    if len(text) >= 2 and text.startswith('"') and text.endswith('"'):
        return text[1:-1]
    if text == "{}":
        return {}
    if text.startswith("[") and text.endswith("]"):
        inner = text[1:-1].strip()
        if not inner:
            return []
        return [_parse_scalar(part, number) for part in _split_inline(inner, number)]
    if text in ("true", "false"):
        return text == "true"
    if text in ("null", "~"):
        return None
    if INTEGER_PATTERN.match(text):
        return int(text)
    if text.startswith("{"):
        raise YamlSubsetError("line %d: inline mapping is not supported" % number)
    return text


def _split_inline(inner, number):
    parts = []
    current = ""
    quoted = False
    for character in inner:
        if character == "'":
            quoted = not quoted
            current += character
            continue
        if character == "," and not quoted:
            parts.append(current)
            current = ""
            continue
        current += character
    if quoted:
        raise YamlSubsetError("line %d: unterminated quoted scalar" % number)
    parts.append(current)
    return [part.strip() for part in parts if part.strip()]
