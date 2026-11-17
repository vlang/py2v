from typing import Any


def probe(label: str) -> Any:
    print(label)
    return label


def either(value: Any) -> Any:
    return value or probe("or-right")


def both(value: Any) -> Any:
    return value and probe("and-right")


if __name__ == "__main__":
    print(either(0))
    print(either("left"))
    print(both(0))
    print(both("left"))
