from typing import Any

def show(data: dict[str, Any], prefix: str, skip: str, enabled: bool) -> None:
    rendered: dict[str, Any] = {
        prefix + key: value if isinstance(value, (list, dict)) else str(value)
        for key, value in data.items() if key != skip
    }
    print(rendered["seen-b"])
    print(len(rendered["seen-list"]))
    records = [prefix] if not enabled else [
        prefix + str(value) for key, value in data.items() if key != skip
    ]
    print(",".join(records))
    keys = {prefix + key for key, value in data.items() if key != skip}
    print("seen-a" in keys)
    print("seen-drop" in keys)

if __name__ == "__main__":
    show({"a": "hello", "b": 7, "list": [1, 2], "drop": "ignored"}, "seen-", "drop", True)
