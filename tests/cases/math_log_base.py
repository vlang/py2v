import math
from math import log


def digits(number: int, base: int) -> int:
    return int(math.log(number, base)) + 1


print(round(math.log(8, 2), 6))
print(round(log(1000, 10), 6))
print(round(math.log(math.e), 6), round(log(1), 6))
print(digits(1000, 4))
