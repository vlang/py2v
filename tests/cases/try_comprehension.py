import sqlite3
from typing import Any


def collect(conn: sqlite3.Connection, query: str) -> None:
    try:
        values = [row[0] for row in conn.execute(query).fetchall()]
    except sqlite3.Error:
        values = []
    print(len(values))


def handlers(conn: sqlite3.Connection, kind: int) -> None:
    try:
        if kind == 1:
            raise ValueError("fallback")
        if kind == 2:
            raise TypeError("fallback")
        values = [row[0] for row in conn.execute("SELECT 2").fetchall()]
    except ValueError:
        values = [7]
    except TypeError:
        values = [8]
    print(len(values), values[0])


def returning(conn: sqlite3.Connection, query: str) -> None:
    try:
        values = [row[0] for row in conn.execute(query).fetchall()]
    except sqlite3.Error:
        print("returned")
        return
    print(len(values))


def reraising(conn: sqlite3.Connection, query: str) -> None:
    try:
        values = [row[0] for row in conn.execute(query).fetchall()]
    except sqlite3.Error:
        raise
    print(len(values))


def dynamic_collect(items: list[Any]) -> None:
    try:
        values = [item.get("x") for item in items]
    except AttributeError:
        values = []
    print(len(values))
    if len(values) > 0:
        print(values[0])


if __name__ == "__main__":
    conn = sqlite3.connect(":memory:")
    collect(conn, "SELECT 1")
    collect(conn, "SELECT missing")
    handlers(conn, 0)
    handlers(conn, 1)
    handlers(conn, 2)
    returning(conn, "SELECT 1")
    returning(conn, "SELECT missing")
    reraising(conn, "SELECT 1")
    try:
        reraising(conn, "SELECT missing")
    except sqlite3.Error:
        print("reraised")
    dynamic_collect([{"x": 3}])
    dynamic_collect([1])
    conn.close()
