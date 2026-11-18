def unpacked(upper: int) -> int:
    left, value = 1, 8
    for value in range(upper):
        if value == 1:
            value = 20
            break
    else:
        print(value)
    return left + value


def distinct(N: int) -> int:
    for n in range(N):
        print(n)
    return N


def parameter(value: int) -> int:
    for value in range(value):
        print(value)
    return value


def dynamic_parameter(value):
    for value in [3, 6]:
        pass
    return value


def nested() -> int:
    result = 0
    for value in [1, 2]:
        for value in [4, 5]:
            pass
        result += value
    return result


if __name__ == "__main__":
    print(unpacked(0))
    print(unpacked(3))
    print(distinct(2))
    print(parameter(2))
    original = "initial"
    print(dynamic_parameter(original))
    print(original)
    print(nested())
