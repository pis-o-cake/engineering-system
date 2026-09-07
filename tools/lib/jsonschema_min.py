"""schemas/*.json이 쓰는 keyword만 구현한 최소 JSON Schema 검증기.

지원하지 않는 keyword를 만나면 검증을 건너뛰지 않고 SchemaFeatureError를 던진다.
검증기가 조용히 통과시키는 순간 schema는 다시 장식용 문서가 되기 때문이다. schema에
새 keyword를 추가하려면 여기에도 구현을 추가해야 한다.
"""

SUPPORTED_KEYWORDS = frozenset(
    [
        "$schema",
        "$id",
        "title",
        "description",
        "type",
        "required",
        "properties",
        "additionalProperties",
        "items",
        "const",
        "enum",
        "minLength",
        "minItems",
        "minProperties",
    ]
)

_TYPE_CHECKS = {
    "object": lambda value: isinstance(value, dict),
    "array": lambda value: isinstance(value, list),
    "string": lambda value: isinstance(value, str),
    "boolean": lambda value: isinstance(value, bool),
    "null": lambda value: value is None,
    "integer": lambda value: isinstance(value, int) and not isinstance(value, bool),
    "number": lambda value: isinstance(value, (int, float)) and not isinstance(value, bool),
}


class SchemaFeatureError(Exception):
    """이 검증기가 구현하지 않은 schema keyword를 만났을 때 발생한다."""


def validate(instance, schema, path="$"):
    """instance가 schema를 만족하는지 검사한다.

    Args:
        instance: 검사할 값.
        schema: JSON Schema dict.
        path: 오류 메시지에 쓸 현재 위치.

    Returns:
        오류 문자열 list. 비어 있으면 통과.

    Raises:
        SchemaFeatureError: schema가 미구현 keyword를 쓰는 경우.
    """
    unsupported = sorted(set(schema) - SUPPORTED_KEYWORDS)
    if unsupported:
        raise SchemaFeatureError(
            "%s: schema uses unimplemented keywords: %s" % (path, ", ".join(unsupported))
        )

    errors = []
    expected_type = schema.get("type")
    if expected_type is not None:
        check = _TYPE_CHECKS.get(expected_type)
        if check is None:
            raise SchemaFeatureError("%s: unsupported type '%s'" % (path, expected_type))
        if not check(instance):
            return ["%s: expected %s, got %s" % (path, expected_type, _describe(instance))]

    if "const" in schema and instance != schema["const"]:
        errors.append("%s: expected constant %r, got %r" % (path, schema["const"], instance))
    if "enum" in schema and instance not in schema["enum"]:
        errors.append("%s: %r is not one of %r" % (path, instance, schema["enum"]))
    if "minLength" in schema and isinstance(instance, str):
        if len(instance) < schema["minLength"]:
            errors.append("%s: shorter than minLength %d" % (path, schema["minLength"]))

    if isinstance(instance, dict):
        errors.extend(_validate_object(instance, schema, path))
    elif isinstance(instance, list):
        errors.extend(_validate_array(instance, schema, path))
    return errors


def _validate_object(instance, schema, path):
    errors = []
    if "minProperties" in schema and len(instance) < schema["minProperties"]:
        errors.append("%s: fewer than minProperties %d" % (path, schema["minProperties"]))
    for name in schema.get("required", []):
        if name not in instance:
            errors.append("%s: missing required property '%s'" % (path, name))

    properties = schema.get("properties", {})
    additional = schema.get("additionalProperties", True)
    for name in sorted(instance):
        child_path = "%s.%s" % (path, name)
        if name in properties:
            errors.extend(validate(instance[name], properties[name], child_path))
            continue
        if additional is False:
            errors.append("%s: unknown property '%s'" % (path, name))
            continue
        if isinstance(additional, dict):
            errors.extend(validate(instance[name], additional, child_path))
    return errors


def _validate_array(instance, schema, path):
    errors = []
    if "minItems" in schema and len(instance) < schema["minItems"]:
        errors.append("%s: fewer than minItems %d" % (path, schema["minItems"]))
    item_schema = schema.get("items")
    if isinstance(item_schema, dict):
        for position, item in enumerate(instance):
            errors.extend(validate(item, item_schema, "%s[%d]" % (path, position)))
    return errors


def _describe(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, dict):
        return "object"
    if isinstance(value, list):
        return "array"
    if isinstance(value, str):
        return "string"
    if isinstance(value, int):
        return "integer"
    return type(value).__name__
