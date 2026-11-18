def replacement(values: list[int]) -> list[int]:
    print("replacement")
    values.append(8)
    return [5, 6]


def bound() -> int:
    print("bound")
    return 1


def main():
    a = [1, 2, 3]
    b = a
    b[bound():2] = replacement(a)
    print(a, b)
    b[:2] = reversed(b[:2])
    print(a)


if __name__ == "__main__":
    main()
