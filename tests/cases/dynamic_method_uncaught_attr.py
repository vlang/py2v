from typing import Any


def fail(value: Any) -> None:
    value.append(2)


if __name__ == "__main__":
    fail(1)
