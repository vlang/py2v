from typing import TypeAlias
Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63
print(f'{str(HIGH)!r:>25}')
