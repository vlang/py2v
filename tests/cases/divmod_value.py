def integer(a: int, b: int) -> int:
    return divmod(a, b)[0] * 10 + divmod(a, b)[1]


def floating(a: float, b: float) -> float:
    q, r = divmod(a, b)
    return q * 10.0 + r


def argument(value: int) -> int:
    print(value)
    return value


if __name__ == "__main__":
    print(integer(7, 3))
    print(integer(-7, 3))
    print(integer(7, -3))
    print(floating(7.5, 2.0))
    result = divmod(argument(7), argument(3))
    print(result[0])
    print(result[1])
