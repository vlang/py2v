from typing import TypeAlias

Bitboard: TypeAlias = int
Color: TypeAlias = bool
EMPTY: Bitboard = 0
MASK: Bitboard = 0xffff_ffff_ffff_ffff

class Side:
    def __init__(self, active: Color) -> None:
        self.occupied = [EMPTY, EMPTY]
        self.occupied[active] = MASK

    def get(self, active: Color) -> Bitboard:
        return self.occupied[active]

if __name__ == "__main__":
    side = Side(True)
    print(side.get(False))
    print(side.get(True))
