from typing import Any


def fallback() -> str:
    print("default evaluated")
    return "fallback"


def key() -> str:
    print("key evaluated")
    return "present"


def show(data: dict[str, Any]) -> None:
    print(data.get(key(), fallback()))
    print(data.get("missing", fallback()))


if __name__ == "__main__":
    show({"present": "hello"})
