from typing import Any


def read_config() -> dict[str, Any]:
    return {"zeta": 2, "alpha": "value"}


def show_keys(keys: list[str]) -> None:
    print(":".join(keys))


if __name__ == "__main__":
    config = read_config()
    show_keys(list(config))
