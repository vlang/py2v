from typing import TypeAlias

Word: TypeAlias = int
HIGH: Word = 1 << 63


def probe(value: Word) -> None:
    print(sorted([2, 1], key=lambda item: value))


probe(HIGH)
