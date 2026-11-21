from dataclasses import dataclass
from typing import TypeAlias
Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63
@dataclass
class Board:
    value: Bitboard = HIGH
print(Board().value)
