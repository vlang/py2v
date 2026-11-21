from typing import TypeAlias

Bitboard: TypeAlias = int
MASK: Bitboard = 0xffff_ffff_ffff_ffff
FILE_H: Bitboard = 0x0101_0101_0101_0101 << 7
PLAIN_MASK = 0xffff_ffff_ffff_ffff

OtherWidth = int
OTHER_MASK: OtherWidth = 1 << 63

SignedWidth = int
SIGNED_NEGATIVE: SignedWidth = -1
SIGNED_SMALL: SignedWidth = 1 << 30

class Board:
    bits: Bitboard

    def __init__(self, bits: Bitboard) -> None:
        self.bits = bits

    def low(self) -> Bitboard:
        return self.bits & -self.bits

def full() -> Bitboard:
    return MASK

def negative() -> SignedWidth:
    return SIGNED_NEGATIVE

def show(bits: Bitboard, count: int) -> None:
    print(full())
    print(PLAIN_MASK)
    print(OTHER_MASK)
    print(negative())
    print(SIGNED_SMALL & 0)
    print(bits & -bits)
    print(bits & (bits - 1))
    print((bits + bits) & MASK)
    print((bits * 3) & MASK)
    print((~bits) & MASK)
    print((FILE_H << count) & MASK)
    print(bits >> count)
    print((bits << 64) & MASK)
    print(bits >> 64)
    print(bits | 0)
    print(bits ^ MASK)
    print(bits.bit_length())
    print(bits.bit_count())
    print(bits > -1)
    print(bits > count)
    print(count < bits)
    print(bits != 0)

if __name__ == "__main__":
    show(MASK, 7)
    board = Board(MASK)
    print(board.low())
