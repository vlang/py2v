def main():
    a = [[1]]
    copied = a.copy()
    copied[0].append(2)
    print(a, copied)
    sliced = a[:]
    sliced[0].append(3)
    print(a)
    listed = list(a)
    listed[0].append(4)
    print(a)
    for i, row in enumerate(a):
        row.append(i + 5)
    print(a)
    values = {"row": a[0]}
    for row in values.values():
        row.append(6)
    for name, row in values.items():
        row.append(7)
    print(a)


if __name__ == "__main__":
    main()
