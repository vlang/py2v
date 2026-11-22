def main() -> None:
    values = [1e16, 1.0, -1e16]
    values[1] = 1
    print(sum(values))

if __name__ == '__main__':
    main()
