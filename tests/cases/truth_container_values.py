from typing import Any


def native_text() -> None:
    record: dict[str, Any] = {"full": "text", "empty": ""}
    if record["full"]:
        print("native")
    print(not record["empty"])


def report(items: list[int], data: dict[str, int]) -> None:
    print(len(items or []))
    print(len(items and [8]))
    print(len(data or {}))
    print(len(data and {"selected": 9}))
    print(len(data or {"default": 7}))


if __name__ == "__main__":
    native_text()
    empty: dict[str, int] = {}
    full = {"key": 1, "other": 2}
    report([], empty)
    report([1, 2], full)
