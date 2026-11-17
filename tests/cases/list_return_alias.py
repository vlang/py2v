def same(values: list[int]) -> list[int]:
    return values


def main():
    a = [1, 2]
    b = same(a)
    b.append(3)
    print(a, b)


if __name__ == "__main__":
    main()
