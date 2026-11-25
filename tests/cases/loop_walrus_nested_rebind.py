def f(flag: bool) -> int:
    if flag and (x := 10) > 0:
        pass
    for x in [1, 2]:
        for x in range(0):
            pass
    return x


def g(flag: bool) -> int:
    if flag and (x := 10) > 0:
        pass
    for x in [1, 2]:
        for x in [3, 4]:
            pass
    return x


if __name__ == "__main__":
    print(f(False))
    print(f(True))
    print(g(False))
    print(g(True))
