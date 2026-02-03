def outer(x: int) -> int:
    def inner(y: int) -> int:
        return y * 2

    return inner(x) + 1


def make_adder(n: int):
    def adder(x: int) -> int:
        return x + n

    return adder


def main():
    print(outer(5))
    print(outer(10))

    add5 = make_adder(5)
    print(add5(10))
    print(add5(20))


if __name__ == "__main__":
    main()
