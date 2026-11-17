from typing import Any


def fail(value: Any) -> None:
    value.join([1])


if __name__ == "__main__":
    fail("")
