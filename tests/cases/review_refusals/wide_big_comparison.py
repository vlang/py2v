from typing import TypeAlias

Word: TypeAlias = int
MASK: Word = 0xffff_ffff_ffff_ffff


def show(word: Word) -> None:
    large = 2 ** 100
    print(word < large)


show(MASK)
