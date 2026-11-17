GLOBAL = frozenset({"alpha", "beta"})
SIGNED = frozenset([-0.0])


def item() -> int:
    print("left")
    return 1


def members() -> list[int]:
    print("right")
    return [1]


def show() -> None:
    empty = frozenset()
    numbers = frozenset([1, 2, 1])
    words = frozenset("αaα")
    nested = frozenset([(1, 2), (1, 2), (3, 4)])
    equivalent = frozenset([True, 1, 1.0])
    print(len(empty), len(numbers), len(words), len(nested), len(equivalent))
    print(1 in numbers, 3 in numbers)
    print(len(GLOBAL), len(frozenset(())), len(frozenset({})))
    print(item() in frozenset(members()))
    print(frozenset([1.0]))
    print(frozenset([-0.0]))
    number = 1.0
    assert number == 1.0
    print(frozenset([number]))
    print(SIGNED)
    print(1 not in numbers, 3 not in numbers)
    try:
        bad = frozenset([[]])
        print(len(bad))
    except TypeError:
        print("unhashable")
    try:
        print([] in numbers)
    except TypeError:
        print("member error")
    try:
        bad = frozenset(None)
        print(len(bad))
    except TypeError:
        print("not iterable")


if __name__ == "__main__":
    show()
