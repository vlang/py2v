class Counter:
    value: int

    def __init__(self, value: int):
        self.value = value

    def _read(self) -> int:
        return self.value

    def read(self) -> int:
        return self._read()


def read_counter(counter: Counter) -> int:
    if counter._read() > 0:
        return counter._read()
    return 0


if __name__ == "__main__":
    counter = Counter(7)
    print(counter.read())
    print(read_counter(counter))
