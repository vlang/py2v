def halved(value: int) -> float:
    return value / 2


def converted(value: int):
    return float(value)


def filtered(values: list[float]) -> float:
    return sum(value for value in values if value != 0.0)


def seeded_sum(count: int) -> float:
    values = [1 / 2]
    for _ in range(count):
        values.append(2.0)
    reciprocals = [1 / value for value in values]
    return sum(reciprocals)


def collected_sums(width: int) -> list[float]:
    values = [0.0] * width
    values.append(sum(float(value) for value in range(width)))
    return values


print(sum([1e16 + 0.0, halved(1), -1e16 * converted(1)]))
print(sum(halved(value) for value in [1, 2, 3]))
samples = [1.0]
print(sum(value for value in samples if value < 0.0))
print(filtered([1e16, 1.0, -1e16]))
changed = [1e16, 0.0, -1e16]
changed[1] = float(1)
print(sum(changed))
print(seeded_sum(0))
print(seeded_sum(2))
print(collected_sums(0))
print(collected_sums(2))
