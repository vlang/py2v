from typing import TypeAlias

Bitboard: TypeAlias = int
EMPTY: Bitboard = 0
MASK: Bitboard = 0xffff_ffff_ffff_ffff

class Board:
    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self.low = EMPTY
        self.full = MASK

    def choose(self, side: int) -> Bitboard:
        if side == 0:
            bits = self.low
        elif side == 1:
            bits = self.full
        else:
            assert False
        return bits >> 1

if __name__ == "__main__":
    board = Board()
    print(board.choose(0))
    print(board.choose(1))
