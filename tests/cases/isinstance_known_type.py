def trailing_zeros(a: int) -> int:
    if not isinstance(a, int):
        raise TypeError("Input value must be an integer")
    count = 0
    rest = a
    while rest > 0 and rest % 2 == 0:
        rest = rest // 2
        count += 1
    return count


def describe(x: float, name: str) -> str:
    if isinstance(x, (int, float)) and isinstance(name, str):
        return name + " is a number"
    return name + " is not a number"


def is_text(n: int) -> str:
    if isinstance(n, str):
        return "text"
    return "not text"


def total(items: list[int]) -> int:
    if not isinstance(items, list):
        return -1
    result = 0
    for item in items:
        result += item
    return result


def run() -> None:
    values: list[int] = [1, 2, 3]
    print(trailing_zeros(8))
    print(describe(2.5, "x"))
    print(is_text(4))
    print(total(values))


run()
