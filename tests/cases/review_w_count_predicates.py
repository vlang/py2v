def pred(x: int) -> bool:
    print('pred', x)
    return x > 1

def main() -> None:
    print(len([x for x in [1, 2, 3] if pred(x)]))
    print(len([x for x in [1, 2, 3] if pred(x) if pred(x + 1)]))

if __name__ == '__main__':
    main()
