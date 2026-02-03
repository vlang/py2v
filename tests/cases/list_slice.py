def main():
    nums = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

    # Basic slicing
    print(nums[2:5])
    print(nums[:3])
    print(nums[7:])

    # Negative indices
    print(nums[-3:])
    print(nums[:-2])

    # With step
    print(nums[::2])
    print(nums[1::2])

    # Reverse
    print(nums[::-1])


if __name__ == "__main__":
    main()
