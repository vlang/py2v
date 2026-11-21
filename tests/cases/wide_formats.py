from typing import TypeAlias

Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63
MASK: Bitboard = 0xffff_ffff_ffff_ffff


def show(value: Bitboard) -> None:
    print(str(value))
    print(bin(value))
    print(hex(value))
    print("%x" % value)


if __name__ == "__main__":
    show(HIGH)
    show(MASK)
