import argparse
from typing import Any

def receiver(holder: Any) -> Any:
    print("receiver")
    return holder

def assigned() -> int:
    print("value")
    return 7

def write(holder: Any) -> None:
    receiver(holder).number = assigned()

def seed(holder: Any) -> None:
    holder.default_map = {"old": 1}

def merge(holder: Any, config: dict[str, Any]) -> None:
    result: dict[str, Any] = {}
    if holder.default_map:
        result.update(holder.default_map)
    result.update(config)
    holder.default_map = result

def show(holder: Any) -> None:
    seed(holder)
    write(holder)
    merge(holder, {"new": "two"})
    print(holder.number)
    print(holder.default_map["old"])
    print(holder.default_map["new"])

if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="attrs")
    args: list[str] = []
    show(parser.parse_args(args))
    try:
        write(7)
    except AttributeError:
        print("rejected")
