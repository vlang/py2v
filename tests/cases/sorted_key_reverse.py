class Item:
    def __init__(self, name: str, weight: int) -> None:
        self.name = name
        self.weight = weight


def heavy(item: Item) -> int:
    return item.weight


def negate(x: int) -> int:
    return -x


def main() -> None:
    nums = [5, -3, 2, -8, 1]
    print(sorted(nums, reverse=True))
    print(sorted(nums, key=abs))
    print(sorted(nums, key=abs, reverse=True))
    print(sorted(nums, key=negate))
    words = ["pear", "Fig", "apple", "kiwi", "Date"]
    print(sorted(words, key=len))
    print(sorted(words, key=len, reverse=True))
    print(sorted(words, key=str.lower))
    print(sorted(words, reverse=True))
    rows = [[3, 1], [1, 2], [2, 0], [1, 0]]
    print(sorted(rows, key=lambda r: r[0]))
    print(sorted(rows, key=lambda r: r[1], reverse=True))
    items: list[Item] = [Item("b", 2), Item("a", 2), Item("c", 1)]
    by_weight = sorted(items, key=lambda it: it.weight)
    for item in by_weight:
        print(item.name, item.weight)
    nums.sort(reverse=True)
    print(nums)
    nums.sort(key=abs)
    print(nums)
    words.sort(key=len)
    print(words)
    words.sort(key=str.lower, reverse=True)
    print(words)
    rows.sort(key=lambda r: r[1])
    print(rows)
    items.sort(key=heavy, reverse=True)
    for item in items:
        print(item.name, item.weight)
    items.sort(key=lambda it: it.name)
    for item in items:
        print(item.name, item.weight)


if __name__ == "__main__":
    main()
