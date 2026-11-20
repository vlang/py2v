def edit(a: list[int]) -> list[int]:
    a[0:1] = [5, 6]
    return a
x = [1, 2, 3]
print(edit(x))
print(x)
