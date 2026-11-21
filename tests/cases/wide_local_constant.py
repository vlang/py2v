from typing import TypeAlias
Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63
ALL: Bitboard = (1 << 64) - 1

def f(a: Bitboard) -> None:
    b = 1 << 63
    c = HIGH
    print(a == b)
    print(a == c)
    print(b)
    print((a + b) & ALL)

f(HIGH)
