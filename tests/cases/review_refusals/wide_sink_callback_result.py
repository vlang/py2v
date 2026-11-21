from typing import Callable, TypeAlias

Word: TypeAlias = int
HIGH: Word = 1 << 63


def read() -> Word:
    return HIGH


def probe(get_word: Callable[[], Word]) -> None:
    print(oct(get_word()))


probe(read)
