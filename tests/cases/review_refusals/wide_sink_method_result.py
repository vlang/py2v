from typing import TypeAlias

Word: TypeAlias = int
HIGH: Word = 1 << 63


class Box:
    def read(self) -> Word:
        return HIGH


def probe(box: Box) -> None:
    print(oct(box.read()))


probe(Box())
