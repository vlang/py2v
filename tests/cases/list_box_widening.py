from typing import Any


def append_text(values: Any) -> None:
    values.append("x")


def main():
    source = [1]
    append_text(source)
    print(source)


if __name__ == "__main__":
    main()
