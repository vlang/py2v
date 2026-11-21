from typing import TypeAlias
Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63

def masked(a: Bitboard, count: int) -> None:
    print((a << 8) & (2**64 - 1))
    print((a << 5) & ((1 << 63) - 1))
    print((a << count) & ((1 << 64) - 1))
    print((a + (1 << 62)) & ((1 << 64) - 1))

masked(HIGH, 12)
