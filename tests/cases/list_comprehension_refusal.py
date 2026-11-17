def grow(values: list[int], value: int) -> int:
    if value == 1:
        values.append(3)
    return value


def main():
    a = [1, 2]
    print([grow(a, value) for value in a])


if __name__ == "__main__":
    main()
