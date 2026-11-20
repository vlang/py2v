def grow(values: list[int]) -> list[int]:
    values.append(3)
    return values


def main() -> None:
    values = [1, 2]
    expected = [1, 2, 3]
    assert grow(values) == expected
    print(values)


if __name__ == "__main__":
    main()
