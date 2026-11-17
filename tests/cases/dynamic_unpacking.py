from typing import Any


def pair(value: Any) -> None:
    first, second = value
    print(first.upper())
    print(second["n"])


def list_pair(value: Any) -> None:
    [first, second] = value
    print(first.upper())
    print(second)


def discarded(value: Any) -> None:
    _, second = value
    print(second)


def pairs(values: Any) -> None:
    for first, second in values:
        print(first.upper())
        print(second["n"])
    else:
        print("done")


def arity(value: Any) -> None:
    try:
        left, right = value
        print(left)
        print(right)
    except ValueError:
        print("arity")


if __name__ == "__main__":
    pair(["ada", {"n": 3}])
    list_pair(["bea", 4])
    discarded([9, 8])
    pairs([["cat", {"n": 5}], ["dog", {"n": 6}]])
    arity([1])
    arity([1, 2, 3])
    arity([1, 2])
