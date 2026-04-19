def make_counter():
    count = 0

    def increment():
        nonlocal count
        count += 1
        return count

    return increment


def make_adder(n: int):
    total = 0

    def add(x: int) -> int:
        nonlocal total
        total += x + n
        return total

    return add


c = make_counter()
print(c())
print(c())

add5 = make_adder(5)
print(add5(1))
print(add5(2))

