from typing import Any


def marker(value: int) -> int:
    print("native", value)
    return value


def report(flag: bool, value: Any) -> None:
    selected = value if flag else []
    result = selected or [marker(1)]
    result.append(2)
    print(selected)
    print(value)
    print(result)
    print(selected or [])


if __name__ == "__main__":
    report(False, [10])
    report(True, [10])
    report(False, [])
    report(True, [])
