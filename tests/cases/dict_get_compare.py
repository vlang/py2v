from typing import Any


def compare(data: dict[str, Any]) -> str:
    return "positive" if data.get("x", 0) > 0 else "nonpositive"


if __name__ == "__main__":
    print(compare({"x": 1}))
    print(compare({}))
