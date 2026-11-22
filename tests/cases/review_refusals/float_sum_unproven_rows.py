def row_sums(rows: list[list[float]]) -> list[float]:
    return [sum(row) for row in rows]


print(row_sums([[0.5, 0.25], []]))
print(row_sums([[1e16, 1.0, -1e16]]))
