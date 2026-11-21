from typing import TypeAlias

Word: TypeAlias = int
HIGH: Word = 1 << 63


def show() -> None:
    word = HIGH
    other = 5
    word, other = -1, 1
    print(word, other)


show()
