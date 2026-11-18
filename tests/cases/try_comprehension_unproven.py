import sqlite3


def missing_handler(conn: sqlite3.Connection) -> None:
    try:
        values = [row[0] for row in conn.execute("SELECT 1").fetchall()]
    except sqlite3.Error:
        pass
    print(len(values))


def conditional_handler(conn: sqlite3.Connection, flag: bool) -> None:
    try:
        values = [row[0] for row in conn.execute("SELECT 1").fetchall()]
    except sqlite3.Error:
        if flag:
            values = []
    print(len(values))


def handler_read(conn: sqlite3.Connection) -> None:
    try:
        values = [row[0] for row in conn.execute("SELECT 1").fetchall()]
    except sqlite3.Error:
        print(len(values))
        values = []
    print(len(values))
