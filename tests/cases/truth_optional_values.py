from typing import Optional


def report(items: Optional[list[int]], data: Optional[dict[str, int]]) -> None:
    print(len(items or []))
    print(len(data or {}))
    if items:
        print("items")
    if data:
        print("data")


if __name__ == "__main__":
    report(None, None)
