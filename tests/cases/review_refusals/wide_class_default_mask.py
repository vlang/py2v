from dataclasses import dataclass
from typing import TypeAlias
Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63
ALL: Bitboard = (1 << 64) - 1
@dataclass
class Board:
    value: Bitboard = (HIGH << 1) & ALL
print(Board().value)
