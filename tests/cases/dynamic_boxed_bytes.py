from typing import Any


def append_bytes(items: Any) -> None:
    items.append(b"AB")
    print(items[0])
    print(items[0].decode())


if __name__ == "__main__":
    append_bytes([])
