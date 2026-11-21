from typing import TypeAlias
Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63
MASK: Bitboard = 0xffff_ffff_ffff_ffff

def identity(n: int) -> int:
    return n

def show(b: Bitboard, signed: int) -> None:
    for i in range(b):
        print(i)
        break

show(HIGH, -1)
