#!/usr/bin/env python3
from typing import Optional


def show(mode: Optional[str] = None, count: int | None = None) -> str:
    label = mode or "default"
    size = count or 7
    return label + str(size)


def first(given: Optional[str], other: Optional[str]) -> str:
    return given or other or "neither"


if __name__ == "__main__":
    print(show("a"), show(None, 0), show("", 2), show(None, 3))
    print(first(None, "b"), first("a", "b"), first(None, None), first("", ""))
