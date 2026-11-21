def accepts_literal(value: float) -> bool:
    return value == -100000000000


if __name__ == "__main__":
    exact = 9007199254740993
    signed_max = 9223372036854775807
    signed_min = -9223372036854775808
    high_bit = 9223372036854775808
    mask = 18446744073709551615
    print(exact)
    print(signed_max)
    print(signed_min)
    print(high_bit)
    print(mask)
    print(mask & exact)
    print(high_bit | 9007199254740993)
    print(mask ^ high_bit)
    print(~high_bit & mask)
    print((mask << 8) & mask)
    print((mask >> 8) & mask)
    print((exact << 63) & mask)
    print(accepts_literal(-100000000000))
