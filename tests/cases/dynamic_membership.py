from typing import Any


def contains(value: Any, needle: str) -> None:
    print(needle in value)
    print(needle not in value)


if __name__ == "__main__":
    contains("abc", "b")
    contains(["a", "c"], "b")
    contains({"b": 1}, "b")
