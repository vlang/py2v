def annotated() -> int:
    value: int = 10
    for value in [2, 4]:
        print(value)
    return value


def shadow(*values: int) -> int:
    result = 0
    for values in values:
        result += values
    return result


if __name__ == "__main__":
    print(annotated())
    print(shadow(2, 3))
