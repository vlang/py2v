import enum


class Status(enum.IntFlag):
    VALID = 0
    BUSY = 1 << 3


STATUS_VALID = Status.VALID
STATUS_BUSY = Status.BUSY


def total() -> int:
    return STATUS_VALID | STATUS_BUSY
