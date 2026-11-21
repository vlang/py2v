from typing import TypeAlias

Word: TypeAlias = int
HIGH: Word = 1 << 63


def probe(value: Word) -> None:
    print(int(value))


probe(HIGH)
