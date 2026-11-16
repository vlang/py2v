count: str = "three"


def total(items: list[int]) -> int:
    count = 0
    for item in items:
        count += item
    return count


def describe(count: int) -> str:
    return "n=" + str(count)


def twice(n: int) -> int:
    count = n
    return count * 2


numbers: list[int] = [1, 2]
print(total(numbers))
print(describe(4))
print(twice(5))
print(count)


def outer() -> int:
    def inner(count: int) -> int:
        return count + 1

    def other() -> int:
        count = 10
        return count * 3

    return inner(1) + other()


print(outer())
