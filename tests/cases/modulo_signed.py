def remainder(a: int, b: int) -> int:
    return a % b


def main() -> None:
    for a in [-7, 7, -6, 6, 0]:
        for b in [3, -3]:
            print(remainder(a, b))
    value = -7
    value %= 3
    print(value)

    def update() -> int:
        nonlocal value
        value %= 3
        return value

    print(update())


if __name__ == "__main__":
    main()
