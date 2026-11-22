def key(n: int) -> int:
    print('key', n)
    return n % 3

def main() -> None:
    values = [5, 3, 2, 6, 1, 4, 0]
    print(sorted(values, key=key, reverse=True))
    values.sort(key=key, reverse=True)
    print(values)
    print(sorted([3, 1, 2, 0], key=key))

if __name__ == '__main__':
    main()
