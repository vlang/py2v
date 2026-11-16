import sqlite3
from datetime import datetime, timedelta


def shift(when: datetime, by: timedelta) -> datetime:
    return when


def open_db(path: str) -> sqlite3.Connection:
    return sqlite3.connect(path)


def label(when: datetime) -> str:
    return when.isoformat()


print(label(shift(datetime(2024, 5, 6), timedelta(days=1))))
conn = open_db(":memory:")
print("opened")
