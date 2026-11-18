from datetime import datetime as Moment, timedelta
from pathlib import Path as FilePath


class Path:
    value: int = 3


class Record:
    path: FilePath = FilePath("base")
    when: Moment = Moment(2024, 1, 2)
    duration: timedelta = timedelta(days=2)
    paths: list[FilePath] = [FilePath("one")]


if __name__ == "__main__":
    record = Record()
    print(str(record.path))
    print(record.when.isoformat())
    print(record.duration.total_seconds())
    print(str(record.paths[0]))
    local = Path()
    print(local.value)
