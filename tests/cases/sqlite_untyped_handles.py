import sqlite3


def count_rows(conn, table):
    return conn.execute("SELECT COUNT(*) FROM " + table).fetchone()[0]


def add(conn, title: str) -> None:
    conn.execute("INSERT INTO notes (title) VALUES (?)", (title,))
    conn.commit()


def titles(cur) -> list:
    cur.execute("SELECT title FROM notes ORDER BY id")
    return [row[0] for row in cur.fetchall()]


def main() -> None:
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE notes (id INTEGER PRIMARY KEY, title TEXT)")
    add(conn, "a")
    add(conn, "b")
    print(count_rows(conn, "notes"))
    print(titles(conn.cursor()))
    conn.close()


if __name__ == "__main__":
    main()
