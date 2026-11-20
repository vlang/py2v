def edit(a: list[int]) -> list[int]:
    del a[0]
    return a
def check() -> None:
    x = [1, 2]
    print(edit(x))
    print(x)
check()
