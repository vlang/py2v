#!/usr/bin/env python3
from typing import Any


def load(flag):
    if flag:
        return {"a": 1}
    return [1, 2]


def show(flag: bool) -> None:
    result: Any = None
    if flag:
        result = load(flag)
    else:
        result = load(False)
    print(result)


def show2(flag: bool) -> None:
    if flag:
        result = load(flag)
    else:
        result = load(False)
    print(result)


def pick(flag: bool, record) -> None:
    try:
        value = record["key"]
    except KeyError:
        value = "missing"
    if flag:
        extra = record.get("other")
    else:
        extra = value
    print(value, extra)


if __name__ == "__main__":
    show(True)
    show2(False)
    pick(True, {"key": 1})
    pick(False, {"key": "k"})
