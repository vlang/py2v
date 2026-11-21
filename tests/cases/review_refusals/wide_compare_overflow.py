from typing import TypeAlias
Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63
print(HIGH < (1 << 64))
