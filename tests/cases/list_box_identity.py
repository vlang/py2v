from typing import Any


def main():
    source = [1]
    records: dict[str, Any] = {"list": source, "label": "kept"}
    rows: list[Any] = [source, 0]
    source.append(2)
    print(len(records["list"]), len(rows[0]))
    records["list"].append(3)
    rows[0].append(4)
    print(source)
    rows[0][0] = 9
    print(source)


if __name__ == "__main__":
    main()
