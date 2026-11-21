from typing import TypeAlias

Word: TypeAlias = int
HIGH: Word = 1 << 63


def probe(value: Word) -> None:
    if value:
        print('taken')


probe(HIGH)
