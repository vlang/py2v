def total(start: int) -> int:
    value = start

    def add(amount: int) -> int:
        nonlocal value
        value += amount

        def finish(extra: int) -> int:
            return value + extra

        return finish(1)

    first = add(2)
    second = add(3)
    return first + second + value


def recursive(n: int) -> int:
    count = 0

    def factorial(k: int) -> int:
        nonlocal count
        count += 1
        if k <= 1:
            return 1
        return k * factorial(k - 1)

    result = factorial(n)
    return result * 10 + count


def conditional(flag: bool) -> int:
    if flag:
        def choose(x: int) -> int:
            return x + 3
        return choose(5)
    return 0


def siblings(n: int) -> int:
    state = n

    def write(x: int) -> int:
        nonlocal state
        state = x
        return state

    def read() -> int:
        return state

    write(9)
    return read() + state


def late_read() -> int:
    value = 1

    def read() -> int:
        return value

    value = 6
    return read()


def default_first() -> int:
    def pick(x: int = 7) -> int:
        return x
    return pick()


def default_second() -> int:
    def pick() -> int:
        return 9
    return pick()


if __name__ == "__main__":
    print(total(10))
    print(recursive(4))
    print(conditional(True))
    print(siblings(3))
    print(late_read())
    print(default_first())
    print(default_second())
