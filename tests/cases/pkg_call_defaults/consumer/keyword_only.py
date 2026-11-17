from ..provider import (
    keyword_only_defaults,
    mixed_keyword_default,
    required_keyword_default,
    keyword_none_default,
    keyword_float_default,
)


def mark_keyword_only(value: int) -> int:
    print("keyword argument", value)
    return value


def run_keyword_only_defaults() -> None:
    print(keyword_only_defaults())
    print(keyword_only_defaults(right=mark_keyword_only(9)))
    print(mixed_keyword_default())
    print(mixed_keyword_default(4, offset=8))
    print(required_keyword_default(1, required=2))
    print(required_keyword_default(value=mark_keyword_only(3), required=mark_keyword_only(4)))
    print(keyword_none_default())
    print(keyword_none_default(payload="present"))
    print(keyword_float_default())
