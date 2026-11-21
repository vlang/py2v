from typing import TypeAlias

Word: TypeAlias = int
HIGH: Word = 1 << 63


class Box:
    value: Word

    def __init__(self) -> None:
        self.value = HIGH


def probe(box: Box) -> None:
    print(oct(box.value))


probe(Box())
