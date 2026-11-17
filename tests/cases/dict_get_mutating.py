from typing import Any


def fallback(data: dict[str, Any]) -> str:
    data["present"] = "changed"
    data["new"] = "inserted"
    print("default evaluated")
    return "fallback"


def show(data: dict[str, Any]) -> None:
    print(data.get("present", fallback(data)))
    print(data.get("new", fallback(data)))


if __name__ == "__main__":
    show({"present": "old"})
