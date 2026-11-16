import sqlite3
from typing import Any


def total(db_conn: Any, least: int) -> int:
    row = db_conn.execute("SELECT COUNT(*) FROM t WHERE n >= ?", (least,)).fetchone()
    return row[0]


def first(conn: object, least: int) -> int:
    row = conn.execute("SELECT n FROM t WHERE n >= ? ORDER BY n", (least,)).fetchone()
    if row is None:
        return -1
    return row[0]


def store(conn: object, n: int) -> None:
    conn.execute("INSERT INTO t (n) VALUES (?)", (n,))
    conn.commit()


def main() -> None:
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE t (n INTEGER)")
    for n in (1, 5, 9):
        store(conn, n)
    print(total(conn, 4))
    print(first(conn, 4), first(conn, 50))


if __name__ == "__main__":
    main()
