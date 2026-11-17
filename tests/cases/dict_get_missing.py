from typing import Any


def show(data: dict[str, Any]) -> None:
    print(data.get("missing"))
    print(data.get("present"))
    print(data.get("zero"))
    print("absent" if data.get("missing") is None else "present")
    print("absent" if None is data.get("missing") else "present")
    print("present" if data.get("present") is not None else "absent")
    print("present" if None is not data.get("zero") else "absent")
    print(data.get("none", "fallback"))
    print(data.get("missing", "fallback"))


if __name__ == "__main__":
    show({"present": "hello", "zero": 0, "none": None})
