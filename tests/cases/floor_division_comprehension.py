def scaled_copy(source: list[int], denominator: int, scale: bool) -> list[int]:
    values = list(source)
    for index in range(len(values)):
        values[index] += 1
    if scale:
        values = [value // denominator for value in values]
    return values


def squared_quotient(value: int, denominator: int) -> int:
    return value**2 // denominator


entries = [20, -20, 8589934593, 25769803775]
print(scaled_copy(entries, 3, False))
print(scaled_copy(entries, 3, True))
print(scaled_copy(entries, -3, True))
print(entries)
print(squared_quotient(140000, 3))
