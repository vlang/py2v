def main():
    a = {1, 2, 3}
    b = {2, 3, 4}

    # Set membership
    print(1 in a)
    print(5 in a)

    # Set operations
    union = a | b
    print(union)

    intersection = a & b
    print(intersection)

    difference = a - b
    print(difference)


if __name__ == "__main__":
    main()
