def main():
    a = True
    b = False

    # Basic operations
    print(a and b)
    print(a or b)
    print(not a)
    print(not b)

    # Compound expressions
    print(a and a)
    print(b or b)
    print((a or b) and (a or b))
    print(not (a and b))

    # Short-circuit evaluation
    x = 5
    print(x > 0 and x < 10)
    print(x < 0 or x > 3)


if __name__ == "__main__":
    main()
