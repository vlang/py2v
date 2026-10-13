class Accumulator:
    def __init__(self, start: int):
        self.total: int = start

    def add(self, n: int) -> int:
        self.total += n
        return self.total


def twice(x: int) -> int:
    return x * 2
