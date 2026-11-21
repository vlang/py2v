def collect(begin: int, end: int, step: int) -> list[int]:
    return list(range(begin, end, step))


def from_bounds(bounds: list[int]) -> int:
    return sum(i * i for i in range(bounds[0], bounds[1]))


limit = -3
print(list(range(limit)))
print(list(range(3, limit)))
print(collect(1, 8, 3))
print(collect(8, 1, -3))
print(collect(1, 8, -3))
print(from_bounds([4, 2]))
print(from_bounds([-2, 2]))
print(list(range(2 ** 3)))
print([value for value in range(2 ** 3, 3 ** 2)])
print(list(range(True)))
