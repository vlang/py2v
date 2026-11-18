import re
import sqlite3
from pathlib import Path
from typing import Callable


def one() -> int:
    print("called")
    return 1


def false_probe() -> bool:
    print("false call")
    return False


def callback() -> Callable[[], int]:
    print("callback")
    return one


def path_probe(value: Path) -> Path:
    print("path")
    return value


def report(connection: sqlite3.Connection) -> None:
    print(bool(connection))
    print(not connection)
    if connection:
        print("connection")
    path = Path("")
    if path_probe(path):
        print("instance")
    print(not path)
    if one:
        print("function")
    print(not one)
    if callback():
        print("factory")
    if false_probe:
        print("bool function")
    print(bool(false_probe()))


if __name__ == "__main__":
    connection = sqlite3.connect(":memory:")
    report(connection)
    connection.close()
    print(bool(connection))
    one()
    missing = re.search("z", "")
    empty = re.search("", "")
    print(bool(missing))
    print(bool(empty))
