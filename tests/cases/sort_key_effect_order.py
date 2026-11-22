def key(value: int) -> int:
    print(value)
    return value % 2


def main() -> None:
    values = [3, 1, 4, 2]
    print(sorted(values, key=key))
    values.sort(key=key, reverse=True)
    print(values)
    print(sorted([5], key=key))


if __name__ == "__main__":
    main()
