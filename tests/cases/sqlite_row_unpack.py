#!/usr/bin/env python3
import sqlite3


def show(conn: sqlite3.Connection) -> None:
    conn.execute("CREATE TABLE people (name TEXT, age INTEGER)")
    conn.execute("INSERT INTO people VALUES ('ada', 36)")
    conn.execute("INSERT INTO people VALUES ('bob', 41)")
    conn.commit()
    row = conn.execute("SELECT name, age FROM people ORDER BY name").fetchone()
    if row:
        name, age = row
        print(name, age)
    missing = conn.execute("SELECT name FROM people WHERE age > 99").fetchone()
    if not missing:
        print("nobody")
    if row and not missing:
        print("one of two")
    for name, age in conn.execute("SELECT name, age FROM people ORDER BY age DESC").fetchall():
        print(name, age)
    rows = conn.execute("SELECT name, age FROM people ORDER BY name").fetchall()
    for name, age in rows:
        print(age, name)
    label = "found" if row else "none"
    print(label)


if __name__ == "__main__":
    show(sqlite3.connect(":memory:"))
