def after_loop(n: int) -> int:
    while True:
        x = n + 1
        break
    return x


def from_branches(n: int) -> str:
    if n > 0:
        label = "pos"
    elif n == 0:
        label = "zero"
    else:
        label = "neg"
    return label


def collected(words: list[str]) -> int:
    for w in words:
        if w.startswith("a"):
            hits = [w]
            total = len(w)
        else:
            hits = []
            total = 0
        if total > 2:
            return len(hits) + total
    return -1


def only_inside(n: int) -> int:
    if n > 3:
        local = n * 2
        return local
    return n


print(after_loop(1), from_branches(2), from_branches(0), from_branches(-1))
print(collected(["b", "abc"]), only_inside(5), only_inside(1))
