from .choice import choose, local_read
from .public import read


def total() -> int:
    saved = choose
    return read() + saved(7, 2) + local_read()
