def main():
    a = [1, 2]
    a[0] = 1
    b = a
    copied = a[:]
    copied[0] = 9
    b.append(3)
    print(a, b, copied)
    other = list(a)
    other[0] = 8
    print(a, other)


if __name__ == "__main__":
    main()
