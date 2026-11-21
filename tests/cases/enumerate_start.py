def letters() -> str:
    print("iterable")
    return "aé"


def offset() -> int:
    print("start")
    return -2


def total(values: list[int], start: int) -> int:
    result = 0
    for i, v in enumerate(values, start=start):
        result += i * v
    return result


for i, char in enumerate(letters(), offset()):
    print(i, char)
print(total([10, 20, 30], 4))
print(total([], 9))
