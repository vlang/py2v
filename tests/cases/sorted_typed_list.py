def check_polygon(nums: list[float]) -> bool:
    sorted_nums = sorted(nums)
    return sorted_nums[-1] < sum(sorted_nums[:-1])


def smallest(items: list[int]) -> int:
    ordered = sorted(items)
    return ordered[0]


def same_digits(a: int, b: int) -> bool:
    return sorted(str(a)) == sorted(str(b))


def main() -> None:
    print(check_polygon([6, 10, 5]))
    print(check_polygon([3, 7, 13, 2]))
    values = [5, 3, 9, 1]
    print(sorted(values))
    print(values)
    print(smallest(values))
    words = ["pear", "apple", "fig"]
    print(sorted(words))
    print(same_digits(125874, 251748))
    print(same_digits(12, 13))
    print(sorted("hello"))


if __name__ == "__main__":
    main()
