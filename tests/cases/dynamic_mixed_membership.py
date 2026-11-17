from typing import Any


def contains(value: Any, words: list[str], record: dict[str, int]) -> None:
    print(value in words)
    print(value in record)
    print(value in "abc")
    print(value not in words)


if __name__ == "__main__":
    contains("b", ["a", "c"], {"b": 1})
    contains("c", ["a", "c"], {"b": 1})
