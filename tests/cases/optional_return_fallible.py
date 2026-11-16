import json
from typing import Optional


def load(text: str) -> Optional[str]:
    data = json.loads(text)
    if not data:
        return None
    return "ok"


def plain(text: str) -> str:
    data = json.loads(text)
    return "ok" if data else "empty"


if __name__ == "__main__":
    first = load("[1]")
    print(first is None, load("[]") is None, plain("[]"))
