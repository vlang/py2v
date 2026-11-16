#!/usr/bin/env python3
import sqlite3


def show(conn: sqlite3.Connection) -> None:
    conn.execute("CREATE TABLE t (n INTEGER, name TEXT)")
    conn.execute("INSERT INTO t VALUES (1, 'a'), (2, 'b')")
    rows = conn.execute("SELECT n, name FROM t ORDER BY n").fetchall()
    ids = [r[0] for r in rows]
    names = [{"id": r[0], "name": r[1]} for r in rows]
    print(ids, len(names))
    firsts = [row[1] for row in conn.execute("SELECT n, name FROM t WHERE n > 1").fetchall() if row[0]]
    print(firsts)


if __name__ == "__main__":
    show(sqlite3.connect(":memory:"))
