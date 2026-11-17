from typing import Any


def alter(rows: list[Any]) -> None:
    rows[0]["record"]["x"] = 2


if __name__ == "__main__":
    record = {"x": 1}
    alter([{"record": record}])
    print(record["x"])
