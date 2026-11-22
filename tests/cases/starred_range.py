def from_tuple(values: tuple[int, int]) -> list[int]:
    return list(range(*values))


def from_list(values: list[int]) -> list[int]:
    return list(range(*values))


def bounds() -> list[int]:
    print("bounds")
    return [7, -2, -3]


print(from_tuple((-2, 4)))
print(from_tuple((4, -2)))
print(from_list([-2]))
print(from_list([4, 8, 2]))
print(list(range(*bounds())))
print(list(range(*(2, 5))))
