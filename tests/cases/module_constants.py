_SECONDS_PER_MINUTE = 60
MAX_SIZE = 3
_lower = 2
NAMES = ["a", "b", "c"]
UNITS = {"k": 1000, "m": 1000000}
DOUBLE = MAX_SIZE * 2
counter = 0
counter = counter + 1


def total() -> int:
    return _SECONDS_PER_MINUTE * MAX_SIZE + _lower + DOUBLE


def pick(i: int) -> str:
    return NAMES[i]


def scale(unit: str) -> int:
    return UNITS[unit]


if __name__ == "__main__":
    print(total())
    print(pick(1))
    print(scale("m"))
    print(counter)
