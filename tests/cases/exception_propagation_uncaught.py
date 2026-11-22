def outer(value: int) -> int:
    return middle(value) + 1


def middle(value: int) -> int:
    return leaf(value)


def leaf(value: int) -> int:
    if value < 0:
        raise ValueError("invalid value")
    return value


outer(-1)
