from typing import Callable


def pick(mode: int) -> Callable[[int], int]:
    if mode == 1:
        def calculate(value: int) -> int:
            return value + 2
    elif mode == 2:
        def calculate(value: int) -> int:
            return value * 2
    else:
        def calculate(value: int) -> int:
            return value - 2
    return calculate


first = pick(1)
second = pick(2)
third = pick(3)
print(first(5), second(5), third(5))
