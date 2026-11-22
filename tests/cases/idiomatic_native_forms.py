def begin() -> int:
    print("begin")
    return 1


def end() -> int:
    print("end")
    return 3


def exercise(text: str, stride: int) -> None:
    for i in range(begin(), end(), 1):
        print(i)
    stop = 3
    for j in range(stop):
        print(j)
        stop = 0
    for k in range(4, -1, stride):
        print(k)
    for unused in range(3, 1):
        print(unused)

    print(len(text))
    print(len(text) // 2)
    print(-7 // 3)
    print(min(stride, 0))
    print(max([1, 2, 3]))

    first = [1, 2]
    second = [3, 4]
    print(first + second)
    print([0, *first, *second, 5])
    print(first, second)
    print([[1]] + [[2]])

    print(len([n for n in [1, 2, 3, 4] if n > 1 if n < 4]))
    print([n for n in first if n > 1])
    copied = [n for n in first]
    first.append(8)
    print(copied)

    values = {3, 1, 2}
    print(any(5 - n in values for n in values))
    print(all(n in values for n in values))


if __name__ == "__main__":
    exercise("é🙂\x00x", -2)
