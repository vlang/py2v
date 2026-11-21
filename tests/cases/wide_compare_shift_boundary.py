from typing import TypeAlias
Bitboard: TypeAlias = int
HIGH: Bitboard = 1 << 63

print(HIGH == (1 << 63))
print(HIGH <= (1 << 62) << 1)
print((1 << 63) >= HIGH)
print(HIGH != (1 << 63))
