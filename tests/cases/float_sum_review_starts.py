def positional(data: list[int], start: int) -> float:
    return sum((value / 2 for value in data), start)


def keyword(data: list[int], start: int):
    return sum((value / 2 for value in data), start=start)


print(positional([], 5))
print(positional([1], 5))
print(keyword([], 7))
print(keyword([1], 7))
k = int("5")
print(sum((x / 2 for x in range(0)), k))
words = ["a", "b"]
print(sum((x / 2 for x in range(0)), len(words)))
print(sum((x / 2 for x in range(0)), True))
