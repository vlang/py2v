a = [1, 2, 3, 4, 5, 6]
b = a
del a[::-2]
print(a, b)
del b[1:3]
print(a, b)
