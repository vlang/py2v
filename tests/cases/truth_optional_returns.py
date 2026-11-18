from __future__ import annotations

from typing import Any, Optional


def maybe(value: Any) -> Optional[Any]:
    print("maybe")
    if value is None:
        return None
    return value


def maybe_object(value: object) -> object | None:
    print("object")
    return value


def report(value: Any) -> None:
    item = maybe(value)
    alias = item
    if item:
        print("yes")
    print(not item)
    print(not alias)
    while item:
        print("loop")
        break
    if maybe(value):
        print("call")
    print(not maybe(value))
    if maybe_object(value):
        print("object call")


if __name__ == "__main__":
    report(None)
    report(0)
    report("")
    report("text")
    report([])
    report([1])
