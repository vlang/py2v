from typing import Callable, TypeAlias

Bitboard: TypeAlias = int
MASK: Bitboard = 0xffff_ffff_ffff_ffff
count: Callable[[Bitboard], int] = getattr(int, "bit_count", lambda value: bin(value).count("1"))
width: Callable[[Bitboard], int] = getattr(int, "bit_length")

def report(value: Bitboard) -> None:
    print(count(value))
    print(width(value))

if __name__ == "__main__":
    report(MASK)
    report(0)
