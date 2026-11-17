from typing import Any


def show(value: Any) -> None:
    print(isinstance(value, int))
    print(isinstance(value, bool))
    print(isinstance(value, float))
    print(isinstance(value, str))
    print(isinstance(value, bytes))
    print(isinstance(value, list))
    print(isinstance(value, dict))
    print(isinstance(value, tuple))
    print(isinstance(value, (str, int)))
    print(isinstance(value, (int, bool)))
    print(isinstance(value, (bool, int)))
    print(isinstance(value, (int, int)))
    print(isinstance(value, (float,)))
    print(isinstance(value, ()))


def subject() -> Any:
    print("subject")
    return "text"


def once() -> None:
    print(isinstance(subject(), (int, str)))
    print(isinstance(subject(), ()))


def nested(record: dict[str, Any]) -> None:
    print(isinstance(record["value"], list))
    print(isinstance(record["value"][0], int))
    print(isinstance(record.get("missing"), str))


if __name__ == "__main__":
    show(3)
    show(True)
    show(2.5)
    show("text")
    show(b"bytes")
    show([1])
    show({"key": 2})
    show(None)
    once()
    nested({"value": [1]})
