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
