from typing import Any


def values_at(data: list[Any]) -> list[int]:
    start, stop, step = data[0], data[1], data[2]
    return list(range(start, stop, step))


print(values_at([-2, 5, 2]))
print(values_at([7, -2, -3]))
print(values_at([2, -1, 1]))
print(values_at([False, True, True]))
