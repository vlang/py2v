def latest(value: int) -> int:
    return value + 10


def from_body(value: int) -> int:
    return latest(value)


saved = latest
before = from_body(1)
print(before)
if from_body(2) == 12:
    def latest(value: int) -> int:
        return value + 20


after = from_body(1)


def total() -> int:
    return after + saved(1)
