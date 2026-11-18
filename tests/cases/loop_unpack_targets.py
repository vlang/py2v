def zipped() -> int:
    result = 0
    for first, second, third in zip([1, 2, 9], [3, 4], [5, 6]):
        result += first + second + third
    return result


def list_target() -> int:
    result = 0
    for [first, second] in [[2, 3], [4, 5]]:
        result += first + second
    return result


def backward() -> int:
    result = 0
    for a, b, c in reversed([[1, 2, 3], [4, 5, 6]]):
        result = result * 10 + a + b + c
    return result


if __name__ == "__main__":
    print(zipped())
    print(list_target())
    print(backward())
