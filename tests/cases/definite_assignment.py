def branches(enabled: bool) -> list[int]:
    if enabled:
        values = [1, 2]
    else:
        values = [3]
    return [value + 1 for value in values]


def handlers() -> list[int]:
    try:
        values = [4]
    except ValueError:
        values = [5]
    return [value + 1 for value in values]


def certain_loop() -> list[int]:
    for count in [6]:
        values = [count]
    return [value + 1 for value in values]


def terminating(enabled: bool) -> list[int]:
    if enabled:
        return [8]
    else:
        values = [9]
    return [value + 1 for value in values]


def while_break() -> list[int]:
    while True:
        values = [10]
        break
    return [value + 1 for value in values]


if __name__ == "__main__":
    print(branches(True))
    print(branches(False))
    print(handlers())
    print(certain_loop())
    print(terminating(True))
    print(terminating(False))
    print(while_break())
