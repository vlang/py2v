def pick(items: list[int], begin: int, end: int, step: int) -> list[int]:
    return items[begin:end:step]


items = [0, 1, 2, 3, 4, 5]
print(pick(items, 100, -100, -2))
print(pick(items, -100, 100, 4))
print(items[:-1:-1], items[::-1], items[2:2:3])
