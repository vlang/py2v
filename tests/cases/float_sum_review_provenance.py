def scaled(values: list[float], factor: float) -> float:
    return sum(value * factor for value in values)


def variance(xs: list[float], mean: float) -> float:
    return sum((x - mean) ** 2 for x in xs) / len(xs)


def weighted_total(prices: list[float], qty: int, rate: float) -> float:
    return sum(price * qty * rate for price in prices)


def updated_work_buffer(scale: int) -> float:
    data = [1e16, 0.5, -1e16]
    data[1] = 1 / 1
    return sum([data[0] * scale, data[1] * scale, data[2] * scale])


print(scaled([1.0, 2.0], 2))
print(scaled([0.5, 0.25], 4))
print(variance([1.0, 2.0, 3.0], 2))
print(variance([1.0, 2.0, 3.0], 2.0))
print(weighted_total([1.5, 2.5], 2, 1))
print(updated_work_buffer(1))
