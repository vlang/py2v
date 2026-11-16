def squares(n: int) -> list[int]:
    out = []
    for i in range(n):
        out.append(i * i)
    return out


def lengths(words: list[str]) -> dict[str, int]:
    table = {}
    for word in words:
        table[word] = len(word)
    return table


def names() -> list[str]:
    found = []
    found.append("a")
    found += ["b"]
    return found


def nested() -> int:
    rows = []
    rows.append([1, 2])
    rows.append([3])
    total = 0
    for row in rows:
        for cell in row:
            total += cell
    return total


words: list[str] = ["aa", "b"]
print(squares(4))
print(lengths(words))
print(names())
print(nested())
