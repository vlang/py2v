from typing import TypeAlias

Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63
MASK: Bitboard = 0xffff_ffff_ffff_ffff


def show(b: Bitboard) -> None:
    print(((b << 1) >> 1) & MASK)


show(HIGH)
