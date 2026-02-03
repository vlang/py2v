def main():
    # Reversed on list
    nums = [1, 2, 3, 4, 5]
    for x in reversed(nums):
        print(x)

    # Reversed on string
    s = "hello"
    for c in reversed(s):
        print(c)

    # Sorted descending
    unsorted = [3, 1, 4, 1, 5]
    for x in sorted(unsorted, reverse=True):
        print(x)


if __name__ == "__main__":
    main()
