from datetime import datetime, timedelta, timezone


def stamp() -> str:
    start = datetime(2024, 1, 31, 12, 30, tzinfo=timezone.utc)
    plain = datetime(2023, 12, 25)
    return start.isoformat() + " " + plain.isoformat()


def age_seconds() -> float:
    span = timedelta(1, minutes=90)
    return span.total_seconds()


print(stamp())
print(age_seconds())
print(datetime.fromisoformat("2024-03-01T08:00:00").isoformat())
print(timedelta(hours=1, seconds=5).total_seconds())
