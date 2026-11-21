from typing import TypeAlias

Word: TypeAlias = int
HIGH: Word = 1 << 63


def word() -> Word:
    return HIGH


class Box:
    value: Word

    def __init__(self) -> None:
        self.value = HIGH

    def get(self) -> Word:
        return self.value
