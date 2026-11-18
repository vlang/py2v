def collect(enabled: bool) -> list[int]:
    if enabled:
        values = [1, 2]
    return [value for value in values]


def augmented(enabled: bool) -> list[int]:
    if enabled:
        values = [1, 2]
    else:
        values += [3]
    return [value for value in values]


if __name__ == "__main__":
    print(collect(True))
