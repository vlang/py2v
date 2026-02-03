def main():
    # Sort in place
    nums = [3, 1, 4, 1, 5, 9, 2, 6]
    nums.sort()
    print(nums)

    # Sort descending
    nums2 = [3, 1, 4, 1, 5, 9, 2, 6]
    nums2.sort(reverse=True)
    print(nums2)

    # Sorted (returns new list)
    original = [5, 2, 8, 1, 9]
    sorted_list = sorted(original)
    print(original)
    print(sorted_list)

    # Reverse a list
    items = [1, 2, 3, 4, 5]
    items.reverse()
    print(items)


if __name__ == "__main__":
    main()
