def choose(START: int, /, *, LIMIT: int) -> int:
    LIMIT += START
    return LIMIT


def total(*VALUES: int) -> int:
    result = 0
    for value in VALUES:
        result += value
    return result


def keywords(**OPTIONS) -> dict[str, object]:
    return OPTIONS


if __name__ == "__main__":
    print(choose(2, LIMIT=3))
