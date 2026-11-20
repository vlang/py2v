from typing import Generic, TypeVar

X = TypeVar("X")
Y = TypeVar("Y")


class Packet(Generic[X, Y]):
    pass


def packet() -> Packet[None, int] | None:
    return None


print(packet() is None)
