from typing import Any


def show(data: dict[str, Any]) -> None:
    print(data.get("nested", {}).get("leaf", "empty"))
    print(data.get("missing", {}).get("leaf", "empty"))


if __name__ == "__main__":
    show({"nested": {"leaf": "found"}})
