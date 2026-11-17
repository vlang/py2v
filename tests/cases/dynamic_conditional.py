from typing import Any


def show(value: Any, enabled: bool) -> None:
    selected = value[0] if enabled else None
    print(selected)
    print(bool(selected))
    print(not selected)
    if selected:
        print(selected.upper())
    print(selected is None)
    scalar = value[0] if enabled else "fallback"
    print(scalar.upper())


if __name__ == "__main__":
    show(["present"], True)
    show(["present"], False)
