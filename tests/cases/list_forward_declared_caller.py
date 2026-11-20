def entry() -> None:
    x = [1]
    print(edit(x))
    print(x)
def edit(a: list[int]) -> list[int]:
    a.append(3)
    return a
entry()
