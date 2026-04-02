def main():
    # Floor division
    print(17 // 5)
    print(-17 // 5)

    # Modulo
    print(17 % 5)
    print(-17 % 5)

    # Power
    print(2 ** 10)
    print(3 ** 4)

    # Negative exponent (Python auto-promotes to float)
    print(2 ** -1)
    print(10 ** -2)

    # Power augmented assignment
    b = 2
    b **= 3
    print(b)

    # Combined
    a = 100
    print(a // 7)
    print(a % 7)
    print(a ** 2)

    # Floor division augmented assignment
    c = -7
    c //= 2
    print(c)

    # Negative numbers
    print(-5 // 2)
    print(-5 % 2)


if __name__ == "__main__":
    main()
