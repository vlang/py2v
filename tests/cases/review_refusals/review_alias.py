from typing import TypeAlias

Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63

def show(b: Bitboard) -> None:
    print(b)
    print(b + b)
    print(b - (b + 1))
    print(b << 1)
    print(b * 4)

show(HIGH)
