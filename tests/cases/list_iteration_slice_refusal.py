def main():
    a = [1, 2]
    b = a
    seen = []
    for value in a:
        seen.append(value)
        if value == 1:
            b[:] = [4, 5, 6]
    print(a, seen)


if __name__ == "__main__":
    main()
