from typing import Any


def record() -> dict[str, Any]:
    print("receiver evaluated")
    return {"present": "hello"}


def main() -> None:
    print(record().get("present"))
    print(record().get("missing"))


if __name__ == "__main__":
    main()
