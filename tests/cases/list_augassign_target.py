def replace(rows: list[list[int]]) -> list[int]:
    print("replace")
    rows[0] = [9]
    return [2]


def index() -> int:
    print("index")
    return 0


def main():
    a = [1]
    rows = [a]
    rows[index()] += replace(rows)
    print(a, rows[0])


if __name__ == "__main__":
    main()
