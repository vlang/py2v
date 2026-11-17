from typing import Any


def _local_greet(name: str, prefix: str = "Private") -> str:
    return prefix + " " + name


def _local_shift(value: int, offset: int = -2) -> int:
    return value + offset


def _local_optional(payload: Any = None) -> str:
    return "None" if payload is None else "value"


def _local_mark() -> str:
    print("local argument")
    return "marked"


def _local_checked(value: str = "allowed") -> None:
    if value != "allowed":
        raise ValueError("unexpected")
    print(value)


def run_local_defaults() -> None:
    print(_local_greet("Ada"))
    print(_local_greet(name="Bob"))
    print(_local_shift(8))
    print(_local_optional())
    print(_local_greet(_local_mark()))
    print(_local_greet("Ada", "Explicit"))
    _local_checked()
    _local_checked("allowed")
    try:
        _local_checked("bad")
    except ValueError:
        print("caught")
