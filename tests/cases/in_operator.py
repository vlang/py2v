def main():
    # In list
    nums = [1, 2, 3, 4, 5]
    print(3 in nums)
    print(10 in nums)
    print(10 not in nums)

    # In string
    s = "hello world"
    print("world" in s)
    print("xyz" in s)
    print("xyz" not in s)

    # In dict (checks keys)
    d = {"a": 1, "b": 2}
    print("a" in d)
    print("c" in d)


if __name__ == "__main__":
    main()
