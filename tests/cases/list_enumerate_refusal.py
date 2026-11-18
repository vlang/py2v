def main():
    a = [1, 2]
    b = a
    seen = []
    for index, value in enumerate(a):
        seen.append(value)
        if index == 0:
            b.append(3)
    print(a, seen)


if __name__ == "__main__":
    main()
