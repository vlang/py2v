from typing import Any


def probe() -> Any:
    print("probe")
    return "answer"


def report(value: Any) -> None:
    print(not (value and probe()))
    print(not (value or probe()))
    print(not (value and (probe() or value)))


if __name__ == "__main__":
    report(0)
    report("left")
