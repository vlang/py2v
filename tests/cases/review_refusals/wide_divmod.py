from typing import TypeAlias
Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63
print(divmod(HIGH, 7))
