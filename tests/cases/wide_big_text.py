from typing import TypeAlias

Word: TypeAlias = int
HIGH: Word = 0x8000_0000_0000_0001
MASK: Word = 0xffff_ffff_ffff_ffff


def show(word: Word) -> None:
    large = 2 ** 100
    print(word, str(word), "%x" % word)
    print(word > 9_007_199_254_740_993, word < MASK)
    print(large, str(large), f"{large}")


show(HIGH)
