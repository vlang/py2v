#!/usr/bin/env python3


class Animal:
    pass


class Dog(Animal):
    pass


class Cat(Animal):
    pass


class Bird(Animal):
    pass


def check_single(x) -> bool:
    """Single type isinstance."""
    return isinstance(x, Dog)


def check_tuple(x) -> bool:
    """Tuple of types isinstance."""
    return isinstance(x, (Dog, Cat))


def check_triple(x) -> bool:
    """Three types isinstance."""
    return isinstance(x, (Dog, Cat, Bird))


def check_in_if(x):
    """isinstance in if condition."""
    if isinstance(x, (Dog, Cat)):
        print("pet")
    else:
        print("other")


def check_negated(x) -> bool:
    """Negated isinstance with tuple."""
    return not isinstance(x, (Dog, Cat))


if __name__ == "__main__":
    d = Dog()
    print(check_single(d))
    print(check_tuple(d))
    print(check_triple(d))
    check_in_if(d)
    print(check_negated(d))
