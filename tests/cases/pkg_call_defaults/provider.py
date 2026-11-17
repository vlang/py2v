from typing import Any


def greet(name: str, prefix: str = "Hello") -> str:
    return prefix + " " + name


def shift(value: int, offset: int = -2) -> int:
    return value + offset


def configured(left: int = 5, right: int = 7) -> int:
    return left * 10 + right


def optional(payload: Any = None) -> str:
    return "None" if payload is None else "value"


def side_effect(value: int, count: int = 2) -> int:
    return value * count


def flag_name(flag: bool = False) -> str:
    return "on" if flag else "off"


def scale_value(scale: float = 1.5) -> float:
    return scale


def combine(first: int, second: int, tail: int = 5) -> int:
    return first * 100 + second * 10 + tail


def checked_optional(value: str | None = None) -> None:
    if value is None:
        value = "allowed"
    if value is not None:
        if value != "allowed":
            raise ValueError("unexpected value")
        print(value)


def zero_default(value: float = 0.0) -> float:
    return value


def unit_default(value: float = 1.0) -> float:
    return value


def negative_default(value: float = -2.0) -> float:
    return value


def negative_zero_default(value: float = -0.0) -> float:
    return value


def float_any_default(value: Any = 0.0) -> None:
    print(value)


def int_any_default(value: Any = 0) -> None:
    print(value)


def keyword_only_defaults(*, left: int = 5, right: int = 7) -> int:
    return left * 10 + right


def mixed_keyword_default(value: int = 2, *, offset: int = 3) -> int:
    return value * 10 + offset


def required_keyword_default(value: int, *, required: int, tail: int = 5) -> int:
    return value * 100 + required * 10 + tail


def keyword_none_default(*, payload: Any = None) -> str:
    return "None" if payload is None else "value"


def keyword_float_default(*, scale: float = 0.0) -> float:
    return scale
