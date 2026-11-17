from typing import Any
import json


def payload() -> Any:
    return json.loads('{"name": "ada", "words": ["cat", "dog"]}')


def words() -> Any:
    return ["cat", "dog"]


def text() -> object:
    return "  ada  "


def nothing() -> Any:
    return None


def invoke_callback(callback: Any) -> Any:
    result = callback()
    return result[0]


def invoke_from_list(callbacks: list[Any]) -> Any:
    result = callbacks[0]()
    return result[0]


if __name__ == "__main__":
    print(payload()["name"].upper())
    print(payload()["words"][0])
    for word in payload()["words"]:
        print(word.upper())
    print("name" in payload())
    print(len(words()))
    print([word.upper() for word in words()])
    print(text().strip())
    print(nothing())
