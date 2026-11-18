from .model.item import Item
from .acyclic.consumer import Holder, take, size, named, opaque, nested
from .cycle_b.consumer import answer
from .model.holder import same


def total() -> int:
    item = Item()
    return take(item) + named(item) + same(item) + opaque(0) + nested(0) + answer(0)
