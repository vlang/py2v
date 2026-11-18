def main():
    a = [1]
    b = a
    for value in a:
        if len(b) < 3:
            b.append(value + 1)
    print(a)


if __name__ == "__main__":
    main()
