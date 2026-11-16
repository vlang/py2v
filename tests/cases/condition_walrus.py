def mark(label: str, value: bool) -> bool:
    print(label)
    return value


def number(label: str, value: int) -> int:
    print(label)
    return value


def branch(first: bool):
    if first:
        print("first")
    elif (picked := mark("pick", True)):
        print("second", picked)
    else:
        print("fallback")


def show():
    if (whole := mark("whole", True)):
        print("got", whole)
    else:
        print("miss")
    print("after", whole)

    if (n := number("fresh", 3)) > 2:
        print("fresh-value", n)

    old = 9
    if (old := number("replace", 4)) > 2:
        print("replace-value", old)
    print("replace-after", old)

    a = False
    x = True
    if a and (x := mark("WRONG and", False)):
        print("WRONG and body")
    print("and-after", x)

    if not (negative := mark("not", False)):
        print("not-value", negative)
    print("not-after", negative)

    branch(True)
    branch(False)

    if (left := number("left", 2)) < (right := number("right", 3)):
        print("pair", left, right)

    current = 1
    if current < (current := 2):
        print("snapshot", current)

    if (twice := number("twice-first", 1)) < (twice := number("twice-second", 2)):
        print("twice", twice)

    keep = True
    if keep or (skipped := mark("WRONG or", True)):
        print("or-kept")

    if (one := mark("one", True)) and (two := mark("two", False)):
        print("WRONG pair body")
    else:
        print("two-values", one, two)


show()
