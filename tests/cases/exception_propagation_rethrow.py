def leaf(value: int) -> int:
    if value < 0:
        raise ValueError("invalid value")
    return value


def middle(value: int) -> int:
    try:
        return leaf(value)
    except ValueError:
        raise


def outer(value: int) -> int:
    try:
        return middle(value)
    except ValueError as problem:
        print(str(problem))
        return 0


print(outer(-1))
