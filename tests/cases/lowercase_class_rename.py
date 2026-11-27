from typing import Callable, Union


class box:
    def __init__(self, v: int):
        self.v = v

    @staticmethod
    def zero() -> 'box':
        return box(0)


class lower:
    value: int = 1


class Py2v_lower:
    value: int = 2


class _item:
    value: int = 3


class Item:
    value: int = 4


class _a:
    value: int = 5


class A_struct:
    value: int = 6


class base:
    def __init__(self, x: int):
        self.x = x

    def score(self) -> int:
        return self.x


class child(base):
    def __init__(self, x: int, y: int):
        super().__init__(x)
        self.y = y

    def total(self) -> int:
        return super().score() + self.y


def unwrap(b: box) -> int:
    return b.v


def sum_boxes(xs: list[box], maybe: box | None) -> int:
    total = 0
    for item in xs:
        total += item.v
    if maybe is not None:
        total += maybe.v
    return total


def apply_box(fn: Callable[[box], int], b: box) -> int:
    return fn(b)


def union_box(maybe: Union[box, None]) -> int:
    if maybe is not None:
        return maybe.v
    return -1


def check_box(b: box) -> int:
    if isinstance(b, box):
        return 1
    return 0


def run() -> None:
    b: box = box(7)
    empty: list[box] = []
    empty.append(b)
    print(unwrap(b))
    print(unwrap(box.zero()))
    print(sum_boxes(empty, box(5)))
    print(apply_box(unwrap, box(11)))
    print(union_box(box(13)), check_box(b))
    print(lower().value, Py2v_lower().value)
    print(_item().value, Item().value)
    print(_a().value, A_struct().value)
    print(child(10, 4).total())


run()
