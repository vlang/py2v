def f() -> int:
    def dummy() -> int:
        return 0
    saved = dummy
    for _i in [1, 2, 3]:
        def g() -> int:
            return _i
        if _i == 1:
            saved = g
    return saved()


if __name__ == "__main__":
    print(f())
