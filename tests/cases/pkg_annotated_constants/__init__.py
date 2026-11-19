from typing import TypeAlias

Index: TypeAlias = int
BASE: Index = 3
FLAGS = [1 << BASE]


def total() -> int:
    return FLAGS[0]
