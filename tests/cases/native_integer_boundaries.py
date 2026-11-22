import math


def number(text: str) -> int:
    return int(text)


def count_nonzero(values: list[int]) -> int:
    count = 0
    for value in values:
        if value:
            count += 1
    return count


def shift_last(values: list[int]) -> int:
    print("rhs")
    values.append(20)
    return 5


def last_index() -> int:
    print("index")
    return -1


def main() -> None:
    high = number("9_223_372_036_854_775_807")
    low = number("-9223372036854775808")
    print(number("٢١٤٧٤٨٣٦٤٨"))
    print(number("4294967296"))
    print(number("9007199254740991"))
    print(number("9007199254740992"))
    print(number("9007199254740993"))
    print(number("1099511627776"))
    print(low, high, low + 1, high - 1)
    print(low - low, high + low, low * 1)
    root = number("3037000499")
    print(root * root)
    for count in [0, 1, 63, 64, 65, 4294967296]:
        print(low >> count, high >> count, 0 << count)
    print(number("-1") << 63)
    print(low % -1, high // -3, -7 % 3, 7 % -3)
    quot, rem = divmod(low, high)
    print(quot, rem)
    print(pow(high, 1), pow(1, high), pow(-1, high), pow(0, high))
    print(sum([-1, high], 1), sum([1, -1], low))
    print(sum([1, 2.5]), sum([1, 2.0]))
    print(math.factorial(0), math.factorial(20))
    print(math.isqrt(high), math.gcd(low, 6), math.lcm(high, high))
    print(int(-9223372036854775808.0), int(4294967296.0), int(-4.9))
    for index, value in enumerate([3, 5], high - 1):
        print(index, value)
    values = [7, 11]
    values[last_index()] += shift_last(values)
    print(values)
    print(count_nonzero([-1, 0, 2, 3]))
    for position in range(len(values)):
        print(position + 1)


if __name__ == "__main__":
    main()
    high = number("9223372036854775807")
    low = number("-9223372036854775808")
    print(pow(high, high, low), pow(2, -1, -17), pow(3, low, 17))
    print(pow(5, 0, -1), pow(99, 0, -17))
