#!/usr/bin/env python3
import sqlite3
import subprocess
from pathlib import Path


def show(conn: sqlite3.Connection, flag: bool) -> None:
    if flag:
        rows = conn.execute("SELECT 1, 2").fetchall()
        row = conn.execute("SELECT 3").fetchone()
        result = subprocess.run(["true"], capture_output=True, text=True)
        where = Path("/tmp")
    else:
        rows = conn.execute("SELECT 1 WHERE 0").fetchall()
        row = conn.execute("SELECT 1 WHERE 0").fetchone()
        result = subprocess.run(["false"], capture_output=True, text=True)
        where = Path("here")
    print(len(rows), row is None, result.returncode, where.name)


def count(path: str, fresh: bool) -> int:
    if fresh:
        conn = sqlite3.connect(":memory:")
        cur = conn.cursor()
    else:
        conn = sqlite3.connect(path)
        cur = conn.cursor()
    cur.execute("SELECT 41 + 1")
    return len(cur.fetchall())



if __name__ == "__main__":
    db = sqlite3.connect(":memory:")
    show(db, True)
    show(db, False)
    stamp = Path(".").stat().st_mtime
    print(stamp > 0)
    print(count(":memory:", True), count(":memory:", False))
