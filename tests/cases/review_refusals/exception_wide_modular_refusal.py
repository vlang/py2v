from typing import TypeAlias
Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63

try:
    print(pow(HIGH, 3, 7))
except ValueError:
    print("caught")
