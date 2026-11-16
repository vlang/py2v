import math
from math import factorial, gcd, isqrt


def count_coprime(limit: int) -> int:
    total = 0
    for n in range(1, limit):
        if gcd(n, limit) == 1:
            total += 1
    return total


def is_prime(number: int) -> bool:
    if number < 2:
        return False
    for i in range(2, isqrt(number) + 1):
        if number % i == 0:
            return False
    return True


def choose(n: int, r: int) -> int:
    return factorial(n) // (factorial(r) * factorial(n - r))


print(math.gcd(12, 18), gcd(12, 18))
print(math.isqrt(17), isqrt(99))
print(math.factorial(5), factorial(6))
print(count_coprime(12))
print(is_prime(97), is_prime(91))
print(choose(10, 3))
