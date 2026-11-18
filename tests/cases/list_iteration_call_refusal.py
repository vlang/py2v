def grow(values: list[int]) -> None:
    values.append(3)


def main():
    a = [1, 2]
    b = a
    for value in a:
        if value == 1:
            grow(b)
    print(a)


if __name__ == "__main__":
    main()
