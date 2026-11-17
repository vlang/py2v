from typing import Any


def main():
    source = [1]
    rows: list[Any] = []
    rows.append(0)
    rows.append(source)
    rows.append(source)
    source.append(2)
    print(len(rows[1]), len(rows[2]))
    rows[1].append(3)
    print(source)


if __name__ == "__main__":
    main()
