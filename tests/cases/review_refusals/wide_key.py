from typing import TypeAlias
Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63
MASK: Bitboard = 0xffff_ffff_ffff_ffff

def identity(n: int) -> int:
    return n

def show(b: Bitboard, signed: int) -> None:
    values: dict[int, str] = {0: "zero"}
    values[b] = "high"
    print(values[0], values[b])

show(HIGH, -1)
