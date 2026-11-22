def collect(width: int) -> list[float]:
    values = [0.0] * width
    values.append(sum(float(v) for v in range(width)))
    return values


def total(xs: list[float]) -> float:
    return sum(x / 1 for x in xs)


print(collect(0))
print(collect(2))
print(sum(collect(2)))
print(sum(collect(0)))
print(sum(collect(-1)))
print(total([]) * 2)
print(total([0.5]) * 2)
print(round(total([0.125, 0.25]), 2))
print(total([]) + 1)
print(total([1.5]) ** 2.0)
print(total([]) ** 2.0)
if total([0.75, 0.5]) > 1:
    print("big")
