def main():
    values = [1, 2, 3]
    alias = values
    values[1:2:1] = [8, 9]
    print(values, alias)
    values[:1:1] = []
    print(values, alias)
    values[::1] = [4, 5]
    print(values, alias)
    values[1:0:1] = [7]
    print(values, alias)


if __name__ == "__main__":
    main()
