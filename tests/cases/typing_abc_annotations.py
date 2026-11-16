from collections.abc import Callable, MutableSequence


def bubble(collection: MutableSequence[int]) -> MutableSequence[int]:
    n = len(collection)
    for i in range(n):
        for j in range(n - 1 - i):
            if collection[j] > collection[j + 1]:
                collection[j], collection[j + 1] = collection[j + 1], collection[j]
    return collection


def first(items: MutableSequence[str]) -> str:
    return items[0]


def describe(label: str, hook: Callable | None = None) -> str:
    if hook is None:
        return label + " plain"
    return label + " hooked"


print(bubble([3, 1, 2]))
print(first(["a", "b"]))
print(describe("x"))


def size(items: MutableSequence) -> int:
    return len(items)


print(size([1, 2, 3]))
