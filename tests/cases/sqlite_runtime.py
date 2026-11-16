import sqlite3


def setup(path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(path)
    conn.execute("CREATE TABLE notes (id INTEGER PRIMARY KEY, title TEXT, stars INTEGER)")
    conn.execute("INSERT INTO notes (title, stars) VALUES (?, ?)", ("first", 3))
    conn.execute("INSERT INTO notes (title, stars) VALUES (?, ?)", ("second", 5))
    conn.commit()
    return conn


def titles(conn: sqlite3.Connection, least: int) -> list[str]:
    found = []
    rows = conn.execute("SELECT title, stars FROM notes WHERE stars >= ? ORDER BY id", (least,)).fetchall()
    for row in rows:
        found.append(str(row[0]))
    return found


def count(conn: sqlite3.Connection) -> int:
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM notes")
    row = cur.fetchone()
    return len(conn.execute("SELECT id FROM notes").fetchall())


db = setup(":memory:")
print(titles(db, 4))
print(titles(db, 1))
print(count(db))
db.close()
