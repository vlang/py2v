from ..provider import greet, optional, side_effect, configured, shift, flag_name, scale_value
from .keywords import run_keywords


def mark() -> int:
    print("argument evaluated")
    return 3


def run() -> None:
    print(greet("Ada"))
    print(shift(8))
    print(configured())
    print(optional())
    print(side_effect(mark()))
    print(greet("Ada", "Explicit"))
    print(flag_name())
    print(scale_value())
    run_keywords()


if __name__ == "__main__":
    run()
