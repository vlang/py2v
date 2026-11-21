class Reader:
    def read_number(self, number: int) -> int:
        if number < 0:
            raise IndexError("negative number")
        return number


def collect() -> None:
    reader = Reader()
    print([reader.read_number(number) for number in [3, -1, 5]])


try:
    collect()
except LookupError as problem:
    print(problem)
