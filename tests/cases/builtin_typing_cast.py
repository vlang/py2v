from typing import Any, cast as claim
import typing as hints


def produce() -> int:
    print("once")
    return 8


def cast(first: int, second: int) -> int:
    return first + second


if __name__ == "__main__":
    print(claim(float, 1))
    print(hints.cast(str, "word"))
    print(claim(list[int], [3, 4])[0])
    print(claim(Any, produce()))
    print(cast(4, 5))
