from typing import TypeAlias

Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63

def total(values: list[Bitboard]) -> int:
    return sum(values)

if __name__ == "__main__":
    print(total([HIGH, HIGH]))
