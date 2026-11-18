from typing import Any


def marker(value: int) -> int:
    print("native", value)
    return value


def report(flag: bool, value: Any) -> None:
    selected = value if flag else [marker(1)]
    selected.append(2)
    print(selected)
    print(value)
    print(value if flag else [[marker(3)]])
    print(value if flag else {"key": [marker(4)]})


if __name__ == "__main__":
    report(False, [10])
    report(True, [10])
    report(False, [])
    report(True, [])
