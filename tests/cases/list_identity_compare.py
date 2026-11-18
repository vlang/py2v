def main():
    a = [1]
    b = a
    c = [1]
    print(a is b, a is c, a == c)
    b.append(2)
    print(a, c)
    x = [a]
    y = [[1, 2]]
    print(x == y)


if __name__ == "__main__":
    main()
