def parse(line: str) -> list[int]:
    return list(map(int, line.split()))


def halves(line: str) -> list[float]:
    return list(map(float, line.split(",")))


def texts(numbers: list[int]) -> list[str]:
    return list(map(str, numbers))


def whole(values: list[float]) -> list[int]:
    return list(map(int, values))


def pair(line: str) -> int:
    a, b = map(int, line.split())
    return a * b


print(parse("3 14 15"))
print(sum(parse("1 2 3")))
print(halves("1.5,2.25"))
print(texts([1, 2, 3]))
print(whole([1.9, 2.1]))
print(pair("6 7"))
print(" ".join(map(str, [4, 5])))
print(sum(map(int, "1234")))
