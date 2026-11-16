def count_ones(a: int) -> int:
    return bin(a).count("1")


def bits(number: int) -> str:
    return bin(number)[2:].zfill(8)


def main() -> None:
    print(bin(5))
    print(bin(0))
    print(bin(-5))
    n = 37
    print(bin(n))
    print(str(bin(n))[2:])
    print(count_ones(255))
    print(bits(10))
    print(len(bin(1 << 10)))
    table = [bin(i).count("1") for i in range(8)]
    print(table)


if __name__ == "__main__":
    main()
