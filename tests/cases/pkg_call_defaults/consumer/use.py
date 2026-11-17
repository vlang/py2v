from ..provider import greet, optional, side_effect, configured, shift, flag_name, scale_value
from .keywords import run_keywords
from ..provider import checked_optional
from .float_defaults import run_float_defaults


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
    checked_optional()
    checked_optional("allowed")
    run_float_defaults()


if __name__ == "__main__":
    run()
