from typing import Any


def marker(value: int) -> int:
    print("native", value)
    return value


def report(flag: bool, value: Any) -> None:
    selected = [marker(1)] if flag else value
    selected.append(2)
    print(selected)
    print(value)
    print([[marker(3)]] if flag else value)
    print({"key": [marker(4)]} if flag else value)


if __name__ == "__main__":
    report(False, [10])
    report(True, [10])
    report(False, [])
    report(True, [])
