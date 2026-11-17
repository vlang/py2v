from typing import Any


def separator() -> str:
    print("separator")
    return "|"


def payload() -> str:
    print("iterable")
    return "aβ"


def placeholders(count: int) -> str:
    return ",".join("?" * count)


def words() -> list[Any]:
    return ["a", "β"]


def invalid_words() -> list[Any]:
    return ["a", 3]


print("|".join("aβ"))
print("|".join("a\u0301😀"))
print("|".join(""))
print("".join("aβ"))
print("|".join("z"))
print(placeholders(3))
print(placeholders(0))
print(placeholders(-2))
print(separator().join(payload()))
print("|".join(["a", "β"]))
print("|".join(words()))
try:
    print("|".join(invalid_words()))
except TypeError:
    print("type-error")
