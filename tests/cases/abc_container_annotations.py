from dataclasses import dataclass
from typing import Iterable, Mapping, Sequence


@dataclass
class Box:
    items: Sequence[int]
    names: Mapping[str, int]


def total(values: Sequence[int]) -> int:
    out = 0
    for v in values:
        out += v
    return out


def longest(words: Iterable[str]) -> int:
    best = 0
    for w in words:
        if len(w) > best:
            best = len(w)
    return best


def lookup(table: Mapping[str, int], key: str) -> int:
    return table[key]


if __name__ == "__main__":
    nums: list[int] = [3, 4, 5]
    words: list[str] = ["a", "abc", "ab"]
    table: dict[str, int] = {"x": 7}
    print(total(nums))
    print(longest(words))
    print(lookup(table, "x"))
    box = Box(nums, table)
    print(total(box.items) + lookup(box.names, "x"))
