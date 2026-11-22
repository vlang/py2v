print(sum([0.1] * 10))
zeros = [0.0] * 0
print(sum(zeros))
halves = [0.5] * 3
print(sum(halves))
tenths = [0.1] * 10
print(sum(tenths))
print(sum([0.1] * -1))


def term() -> int:
    print('evaluated')
    return 1


print(sum([float(term())] * 0))
