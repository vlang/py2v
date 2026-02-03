def main():
    # Basic list comprehension
    squares = [x * x for x in range(5)]
    print(squares)

    # List comprehension with condition
    evens = [x for x in range(10) if x % 2 == 0]
    print(evens)


if __name__ == "__main__":
    main()
