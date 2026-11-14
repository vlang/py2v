from typing import Generic, Protocol, TypeVar

item_type = TypeVar("item_type")


class Probe(Protocol, Generic[item_type]):
    def ping(self) -> int: ...


def echo(item_type: int) -> int:
    return item_type


print(echo(7))
