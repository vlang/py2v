def main():
    a = [1, 2]
    b = a
    for value in a:
        if value == 1:
            b += [3]
    print(a)


if __name__ == "__main__":
    main()
