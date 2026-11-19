from collections.abc import Sequence
from typing import Tuple


def replace(values: Sequence[str], replace_now: bool) -> int:
    if replace_now:
        values = ("replacement",)
    return len(values)


def forward(values: Tuple[str, ...], replace_now: bool) -> int:
    return replace(values, replace_now)


paths = ("first", "second")
print(forward(paths, False))
print(forward(paths, True))
print(len(paths))
