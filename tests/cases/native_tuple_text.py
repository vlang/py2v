def show(values: tuple[int, ...]) -> None:
    print(values, str(values), f"{values!r}")


pair = (3, -1)
single = (8,)
show(pair)
show(single)
print(pair, single)
