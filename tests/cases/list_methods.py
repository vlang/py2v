def main():
    nums = [1, 2, 3]

    # Append
    nums.append(4)
    print(nums)

    # Insert
    nums.insert(0, 0)
    print(nums)

    # Pop
    last = nums.pop()
    print(last)
    print(nums)

    # Remove
    nums.remove(2)
    print(nums)

    # Extend
    nums.extend([5, 6, 7])
    print(nums)

    # Clear
    nums.clear()
    print(nums)


if __name__ == "__main__":
    main()
