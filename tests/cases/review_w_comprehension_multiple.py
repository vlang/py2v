def predicate(x: int) -> bool:
    print('predicate', x)
    return x % 2 == 0

def project(x: int) -> int:
    print('project', x)
    return x * 10

def main() -> None:
    print([project(x) for x in [1, 2, 3, 4] if predicate(x)])
    print([project(x) for x in [1, 2, 3, 4] if predicate(x) if predicate(x + 1) == False])
    print([project(x + y) for x in [1, 2] for y in [1, 2] if predicate(x + y)])

if __name__ == '__main__':
    main()
