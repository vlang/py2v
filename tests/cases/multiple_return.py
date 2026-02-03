def get_pair() -> tuple:
    return (1, 2)


def get_triple() -> tuple:
    return (10, 20, 30)


def divmod_custom(a: int, b: int) -> tuple:
    return (a // b, a % b)


def main():
    x, y = get_pair()
    print(x)
    print(y)

    a, b, c = get_triple()
    print(a)
    print(b)
    print(c)

    quotient, remainder = divmod_custom(17, 5)
    print(quotient)
    print(remainder)


if __name__ == "__main__":
    main()
