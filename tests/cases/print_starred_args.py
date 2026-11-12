xs: list[int] = [1, 2, 3]
empty: list[int] = []
print(*xs, 0)
print("start", *xs, "end")
print(*empty, 0)
print(*xs, *empty)
