def score(x: int):
    return 0 if x == 0 else 2.5 / x


def show(x):
    print(x)


print(score(0), score(2))
print(isinstance(score(0), int), isinstance(score(2), float))
show(0 if 0 == 0 else 9 / 2)
show(0 if 1 == 0 else 9 / 2)
values = [0 if i == 0 else 8 / i for i in (0, 2)]
print(values)
print(isinstance(values[0], int), isinstance(values[1], float))
print(f"{0 if 0 == 0 else 7 / 2}")
print(f"{0 if 1 == 0 else 7 / 2}")
