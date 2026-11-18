from typing import Any

def main():
    source = [1]
    rows: list[Any] = []
    rows.append(0)
    rows.append(source)
    rows[1].append(2)
    print(source)

if __name__ == '__main__':
    main()
