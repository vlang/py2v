from typing import TypeAlias

Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63

def multiply(word: Bitboard) -> None:
    print(word * 4)

if __name__ == "__main__":
    multiply(HIGH)
