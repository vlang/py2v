from typing import TypeAlias
Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63
MASK: Bitboard = 0xffff_ffff_ffff_ffff

def identity(n: int) -> int:
    return n

def show(b: Bitboard, signed: int) -> None:
    try:
        print([0, 1][b])
    except IndexError:
        print("IndexError")

show(HIGH, -1)
