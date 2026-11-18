from typing import Any


def report(flag: bool, value: Any) -> None:
    print(0.0 if flag else value)
    print(value if flag else 2.0)
    print(-0.0 if flag else value)
    print([0.0, -0.0, +2.0, 1.25] if flag else value)
    print(value if flag else {"key": [0.0, -0.0, 2.0]})


if __name__ == "__main__":
    report(True, "text")
    report(False, "text")
