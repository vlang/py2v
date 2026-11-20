def latest(value: int) -> int:
    return value + 10


def from_body(value: int) -> int:
    return latest(value)


saved = latest
print(from_body(1))
if from_body(2) == 12:
    def latest(value: int) -> int:
        return value + 20


print(from_body(1))
print(saved(1))
