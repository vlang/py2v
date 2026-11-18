def show() -> None:
    inner = frozenset([1])
    outer = frozenset([inner])
    print(frozenset([1]) in outer)
    print({1} in outer)
    print(frozenset([2]) in outer)


if __name__ == "__main__":
    show()
