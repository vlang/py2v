from typing import Callable


class Handler:
    callbacks: dict[str, Callable[[int], int]]
    callback: Callable[[int], int]

    def __init__(self, callback: Callable[[int], int]):
        self.callback = callback

    def run(self, value: int) -> int:
        return self.callback(value)


def twice(value: int) -> int:
    return value * 2


handler = Handler(twice)
print(handler.run(3))
