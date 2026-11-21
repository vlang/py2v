from typing import TypeAlias

Word: TypeAlias = int
HIGH: Word = 1 << 63


def probe(value: Word) -> None:
    print(value.to_bytes(8, 'big').hex())


probe(HIGH)
