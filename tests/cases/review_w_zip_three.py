def one() -> list[int]:
    print('one')
    return [1, 2, 3]
def two() -> list[int]:
    print('two')
    return [4, 5]
def three() -> list[int]:
    print('three')
    return [6, 7, 8, 9]
for a, b, c in zip(one(), two(), three()):
    print(a, b, c)
for a, b in zip('é🙂+', [2, 3]):
    print(a, b)
