import json
import sqlite3


def parse(text: str) -> int:
    try:
        data = json.loads(text)
        count = len(data)
    except json.JSONDecodeError as e:
        print("bad json:", str(e)[:12])
        return -1
    else:
        print("parsed")
    return count


def lookup(conn: sqlite3.Connection, table: str) -> int:
    try:
        row = conn.execute("SELECT COUNT(*) FROM " + table).fetchone()
        return row[0]
    except sqlite3.OperationalError:
        return -1
    except Exception as e:
        print("other", e)
        return -2


def insert(conn: sqlite3.Connection, n: int) -> str:
    try:
        conn.execute("INSERT INTO t (n) VALUES (?)", (n,))
        conn.commit()
    except sqlite3.IntegrityError as e:
        return "duplicate: " + str(e)
    return "stored"


def main() -> None:
    print(parse('{"a": 1, "b": 2}'))
    print(parse("{not json"))
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE t (n INTEGER PRIMARY KEY)")
    print(insert(conn, 1))
    print(insert(conn, 1))
    print(lookup(conn, "t"))
    print(lookup(conn, "missing"))


if __name__ == "__main__":
    main()
