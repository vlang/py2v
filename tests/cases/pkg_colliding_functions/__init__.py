from . import left
from .right import read as read_right


def total() -> int:
    return left.read() * 10 + read_right()
