#!/usr/bin/env python3
# V requires both operands of an overloaded operator to have the same type, but
# Python leaves the operand of a comparison unannotated. An unannotated operand
# of `__lt__`/`__eq__`/... must default to the receiver type rather than `Any`.


class Version:
    def __init__(self, major: int):
        self.major: int = major

    def __lt__(self, other) -> bool:
        return self.major < other.major

    def __eq__(self, other) -> bool:
        return self.major == other.major

    def __add__(self, other) -> "Version":
        return Version(self.major + other.major)


def compare(a: Version, b: Version) -> bool:
    return a < b


def add(a: Version, b: Version) -> Version:
    return a + b