def main():
    # Any
    print(any([False, False, True]))
    print(any([False, False, False]))
    print(any([True, True, True]))

    # All
    print(all([True, True, True]))
    print(all([True, False, True]))
    print(all([False, False, False]))

    # With expressions
    nums = [1, 2, 3, 4, 5]
    print(any(x > 3 for x in nums))
    print(all(x > 0 for x in nums))
    print(all(x > 3 for x in nums))


if __name__ == "__main__":
    main()
