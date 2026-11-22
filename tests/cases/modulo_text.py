def render(items: list[int], divisor: int) -> str:
    if divisor == 0:
        raise ValueError("zero divisor")
    result = ""
    for value in items:
        result += str(value % divisor)
    return result


print(render([1, 2, -3, 4], 2))
print(render([1, 2, -3, 4], -3))
print(round(-7))
print(round(15 % 8))
print(round(True))
