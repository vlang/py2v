_BLOCK = 2
LIMIT = 3


def walk(n: int) -> int:
    total = 0
    for start in range(0, n, _BLOCK):
        total += start
    for start in range(0, n, LIMIT):
        total += start
    return total


print(walk(7))
