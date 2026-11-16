from math import pi, sqrt, e, inf, floor, tau
from math import cos as cosine


def area(radius: float) -> float:
    return pi * radius * radius


def smallest(values: list[float]) -> float:
    best = inf
    for value in values:
        if value < best:
            best = value
    return best


print(area(2.0))
print(sqrt(16.0))
print(round(e, 3))
print(smallest([3.5, 1.25]))
print(floor(2.7))
print(round(tau, 4))
print(cosine(0.0))
print(-inf < 0)


def shadow(e: int, values: list[int]) -> int:
    pi = 3
    total = e + pi
    for tau in values:
        total += tau
    return total


print(shadow(1, [2, 3]))
print(round(sqrt(2) * cosine(pi), 6))
n = 49
print(sqrt(n))
