from typing import Any, Optional


def report(value: Optional[Any]) -> None:
    if value:
        print("yes")
    print(not value)


if __name__ == "__main__":
    report(None)
    report(0)
    report("")
    report("x")
