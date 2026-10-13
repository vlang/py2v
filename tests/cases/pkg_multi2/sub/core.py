class Counter:
    def __init__(self, start: int):
        self._total: int = start

    def bump(self, _by: int) -> int:
        self._total += _by
        return self._total


def scale(x: int) -> int:
    return x * 2
