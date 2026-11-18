class EmptyBool:
    def __bool__(self) -> bool:
        print("bool-hook")
        return False


class EmptyLength:
    def __len__(self) -> int:
        print("len-hook")
        return 0


class FullLength:
    def __len__(self) -> int:
        print("full-len-hook")
        return 3


class Both:
    def __bool__(self) -> bool:
        print("both-bool-hook")
        return True

    def __len__(self) -> int:
        print("bad-both-len-hook")
        return 0


class Plain:
    pass


def make_plain() -> Plain:
    print("make-plain")
    return Plain()


def report() -> None:
    a = EmptyBool()
    b = EmptyLength()
    c = FullLength()
    d = Both()
    e = Plain()
    print(not a)
    print(bool(b))
    print(bool(c))
    print(not d)
    print(not e)
    if a:
        print("bad-a")
    else:
        print("a-false")
    if b:
        print("bad-b")
    else:
        print("b-false")
    if c:
        print("c-true")
    if d:
        print("d-true")
    if e:
        print("e-true")
    if make_plain():
        print("factory-true")


if __name__ == "__main__":
    report()
