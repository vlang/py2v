from pathlib import Path
from typing import Optional
import sqlite3


def path_state(value: Optional[Path]) -> None:
    print(1 if value else 0)
    print(not value)
    while value:
        print("path-loop")
        break


def connection_state(value: Optional[sqlite3.Connection]) -> None:
    print(1 if value else 0)
    print(not value)


def cursor_state(value: Optional[sqlite3.Cursor]) -> None:
    print(1 if value else 0)
    print(not value)


if __name__ == "__main__":
    path_state(None)
    path_state(Path(""))
    path_state(Path("not-a-real-file"))
    connection_state(None)
    connection = sqlite3.connect(":memory:")
    connection_state(connection)
    cursor_state(None)
    cursor = connection.cursor()
    cursor_state(cursor)
    connection.close()
    connection_state(connection)
    cursor_state(cursor)
