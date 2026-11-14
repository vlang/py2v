def is_even(n: int) -> bool:
    return n % 2 == 0


def describe(n: int) -> str:
    if (even := is_even(n)):
        print(even)
        return "even"
    print(even)
    return "odd"


if __name__ == "__main__":
    print(describe(4))
    print(describe(7))
