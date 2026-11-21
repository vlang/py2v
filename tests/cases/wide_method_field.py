from typing import TypeAlias

Bitboard: TypeAlias = int
EMPTY: Bitboard = 0
MASK: Bitboard = 0xffff_ffff_ffff_ffff

class Board:
    occupied: Bitboard

    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self.occupied = EMPTY | MASK

    def flip(self) -> None:
        self.occupied = self.occupied ^ MASK

    def population(self) -> int:
        return self.occupied.bit_count()

if __name__ == "__main__":
    board = Board()
    print(board.population())
    board.flip()
    print(board.population())
