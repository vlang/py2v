def show(name: str, n: int, ratio: float, ok: bool) -> None:
    print("hello", name)
    print("n", n, "ratio", ratio)
    print(name, ok)
    print("a", "b", n, sep="-")
    print("cost $", n)
    items = [1, 2]
    print("items", items, len(items))


show("x", 3, 1.5, True)
