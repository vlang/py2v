def append_via_alias(values: list[int]) -> None:
    other = values
    other.append(3)
    values = [9]
    values.append(10)
    print(values)


def borrow_native(values: list[int]) -> None:
    values.append(7)


def append_before_read(left: list[int], right: list[int]) -> None:
    left.append(8)
    print(right)


def split_sum(values: list[int]) -> int:
    if len(values) <= 1:
        return sum(values)
    left: list[int] = []
    right: list[int] = []
    for index, value in enumerate(values):
        if index < len(values) // 2:
            left.append(value)
        else:
            right.append(value)
    return split_sum(left) + split_sum(right)


def main():
    a = [1, 2]
    append_via_alias(a)
    print(a)
    unshared = [5, 6]
    borrow_native(unshared)
    print(unshared)
    read_only = [1, 2]
    read_alias = read_only
    print(read_only, read_alias)
    assert split_sum([1, 2, 3]) == 6
    same = [6]
    append_before_read(same, same)
    print(same)


if __name__ == "__main__":
    main()
