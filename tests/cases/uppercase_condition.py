class Limit:
    def __init__(self, end: int):
        self.end = end


def count() -> int:
    C = Limit(3)
    i = 0
    while i < C.end:
        i += 1
    return i


if __name__ == "__main__":
    print(count())
