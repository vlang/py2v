a = [1, 2]
b = a
frozen = frozenset(a)
b.append(3)
print(len(frozen), 1 in frozen)
print(a, b, a is b)
