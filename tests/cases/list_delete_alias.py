def main():
    a = [1, 2, 3]
    b = a
    del b[1]
    print(a, b)


if __name__ == "__main__":
    main()
