def sum_values(values: list[float]) -> float:
    return sum(values)


result = sum_values([1e16, 1, -1e16])
print(result in (0.0, 1.0))
