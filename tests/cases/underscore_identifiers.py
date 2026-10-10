#!/usr/bin/env python3
# V forbids a leading underscore on variables, struct fields, and methods,
# while Python uses `_name` for private-by-convention and dunders for protocol
# hooks. These must all reach V under a legal spelling, consistently between
# the declaration site and every reference site.


class Registry:
    """Uses __slots__, which must not become a struct field."""

    __slots__ = ("_count",)

    def __init__(self):
        self._count: int = 0

    def bump(self, _by: int) -> int:
        self._count += _by
        return self._count


class Child(Registry):
    def bump(self, _by: int) -> int:
        return super().bump(_by)


def locals_demo() -> int:
    _first: int = 1
    _second: int = 2
    _total: int = _first + _second
    _throwaway, _kept = 3, 4
    return _total + _kept
