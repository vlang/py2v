from typing import Any

def by_index(index: int) -> dict[str, Any]:
    return {"name": "rook", "squares": [index, 8]}

def show(name: str) -> None:
    try:
        config = by_index(["yes"].index(name))
    except ValueError:
        print("missing")
        return
    print(config["name"])
    print(config["squares"])

if __name__ == "__main__":
    show("yes")
    show("no")
