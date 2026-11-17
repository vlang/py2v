def main():
    a = [1, 2]
    b = a
    b.append(3)
    print(a, b)
    a = [9]
    b.append(4)
    print(a, b)
    b[0] = 7
    c = b
    c.pop()
    print(b, c)


if __name__ == "__main__":
    main()
