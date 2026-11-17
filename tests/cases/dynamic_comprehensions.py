from typing import Any


def names(rows: list[Any]) -> None:
    print([row["name"].upper() for row in rows if row["name"]])


def initials(rows: Any) -> None:
    print([row[0] for row in rows])


if __name__ == "__main__":
    names([{"name": "ada"}, {"name": ""}, {"name": "bob"}])
    initials(["ada", "bob"])
