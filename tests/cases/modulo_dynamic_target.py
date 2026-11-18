from typing import Any
import argparse


def index() -> int:
    print('index')
    return 0


def divisor() -> int:
    print('divisor')
    return 3


def receiver(value: Any) -> Any:
    print('receiver')
    return value


def main():
    values: Any = [-7]
    values[index()] %= divisor()
    print(values)
    parser = argparse.ArgumentParser()
    parser.add_argument('--value', type=int, default=-7)
    args = parser.parse_args([])
    receiver(args).value %= divisor()
    print(args.value)


if __name__ == '__main__':
    main()
