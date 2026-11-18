from typing import TypeVar

T = TypeVar("T", int, float)


def remainder(a: T, b: T) -> T:
    return a % b


print(remainder(-7, 3), remainder(7, -3))
print(remainder(float(-7.5), float(3)), remainder(float(7.5), float(-3)))
