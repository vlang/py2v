from typing import Any, Optional


def probe(label: str) -> str:
    print(label)
    return label


def optional_text(value: bool) -> Optional[str]:
    if value:
        return "present"
    return None


def report(items: list[int], data: dict[str, int], count: int, flag: bool) -> None:
    empty_items: list[int] = []
    print(bool(items))
    print(bool(data))
    print(bool(flag))
    print(bool(items or []))
    print(bool(data and {"key": 1}))
    print(bool(count or 2))
    print(bool(items if count else empty_items))
    print(bool(count if count else 2))
    print(bool(count != 0))
    print(bool(True if count else False))


def dynamic(value: Any) -> None:
    print(bool(value or probe("dynamic-or")))
    print(bool(value and probe("dynamic-and")))


if __name__ == "__main__":
    empty: dict[str, int] = {}
    full = {"key": 1}
    report([], empty, 0, False)
    report([1], full, 2, True)
    dynamic(0)
    dynamic("left")
    print(bool(probe("first") or probe("unused-or")))
    print(bool(probe("") and probe("unused-and")))
    print(bool(optional_text(False)))
    print(bool(optional_text(True)))
    print(bool(False or "literal"))
    print(bool(None))
    print(bool(0.0))
    print(bool(-0.25))
