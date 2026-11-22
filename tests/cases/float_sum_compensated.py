values = [1e16, 1.0, -1e16]
print(sum(values))
print(sum([1.0, -1e16], start=1e16))
print(sum([-1e16, 1e16, 1.0], 2.0))
