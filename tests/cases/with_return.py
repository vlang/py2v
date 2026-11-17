import sys


def direct(path: str) -> int:
    with open(path) as source:
        return 11


def branch(path: str, flag: bool) -> int:
    with open(path) as source:
        if flag:
            return 22
        return 33


def nested(path: str) -> int:
    with open(path) as outer:
        with open(path) as inner:
            return 44


def following(path: str) -> int:
    with open(path) as source:
        pass
    return 55


print(direct(sys.argv[0]))
print(branch(sys.argv[0], True))
print(branch(sys.argv[0], False))
print(nested(sys.argv[0]))
print(following(sys.argv[0]))
