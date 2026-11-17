import sqlite3
import re


if __name__ == "__main__":
    connection = sqlite3.connect(":memory:")
    rows = connection.execute("SELECT 1").fetchall()
    empty = connection.execute("SELECT 1 WHERE 0").fetchall()
    if rows:
        print("rows")
    print(not rows)
    print(not empty)
    print(1 if empty else 0)
    while rows:
        print("once")
        break
    if connection.execute("SELECT 1").fetchall():
        print("call")
    cursor = connection.execute("SELECT 1")
    if cursor.fetchmany(1):
        print("many")
    print(not cursor.fetchmany(1))
    connection.close()
    if re.findall("x", "x"):
        print("findall")
    print(not re.findall("x", ""))
    pattern = re.compile("x")
    if pattern.findall("x"):
        print("pattern-findall")
    if re.split("x", "x"):
        print("split")
    if pattern.split("x"):
        print("pattern-split")
