from typing import Any


def append_number(values: Any, number: Any) -> None:
    values.append(number)


def main():
    source = [1]
    append_number(source, 2 ** 40)
    print(source)


if __name__ == "__main__":
    main()
