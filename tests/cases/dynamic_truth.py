from typing import Any


def report(value: Any) -> None:
    print(bool(value))
    print(not value)


def invert(value: bool) -> bool:
    return not value


def combined(left: Any, right: int) -> None:
    if left + right:
        print("nonzero")
    else:
        print("zero")


if __name__ == "__main__":
    report(0)
    report(1)
    report("")
    report("a")
    report([])
    report([1])
    report({})
    report({"x": 1})
    report(None)
    print(invert(True))
    combined(0, 0)
    combined(1, 0)
