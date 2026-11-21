from typing import TypeAlias

Word: TypeAlias = int
HIGH: Word = 1 << 63


def show() -> None:
    word = HIGH
    for word in [-1]:
        print(word)
    print(word)


show()
