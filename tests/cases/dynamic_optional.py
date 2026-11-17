from typing import Any, Optional


def show(items: Any, value: Optional[str]) -> None:
    items.append(value)
    print(items[-1])


if __name__ == "__main__":
    show([], None)
    show([], "")
    show([], "present")
