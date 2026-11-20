def has_small_value(items: list) -> bool:
    for i, value in enumerate(items):
        if value < i:
            return True
    return False


def minimum(items: list[int | float], last: int) -> int | float:
    if last == 0:
        return items[0]
    previous = minimum(items, last - 1)
    current = items[last]
    return previous if previous <= current else current


print(has_small_value([3, 0.5]), has_small_value([3, 2.5]))
print(minimum([2, 1, 3], 2) == minimum([1], 0))
