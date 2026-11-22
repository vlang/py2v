def weighted(first: int, middle: int, last: int) -> int:
    if middle == 0:
        raise ValueError("middle cannot be zero")
    return first * 100 + middle * 10 + last


def score(values: list[int]) -> int:
    start = values[0]
    return weighted(last=3, middle=start, first=-2)


print(score([10]))
print(weighted(middle=2, first=3, last=1))
