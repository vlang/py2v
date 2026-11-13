def difference(a: int, b: int) -> int:
    return a - b


def main() -> None:
    runner = difference
    print(difference(b=2, a=5) + runner(b=5, a=2))


if __name__ == "__main__":
    main()
