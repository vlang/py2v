from typing import Generic, TypeVar

T = TypeVar('T')
ItemType = TypeVar('ItemType')
Key = TypeVar('Key')
Value = TypeVar('Value')
_Inner = TypeVar('_Inner')

class Box(Generic[ItemType]):
    def __init__(self, item: ItemType) -> None:
        self.item: ItemType = item

    def get(self) -> ItemType:
        return self.item

class Pair(Generic[Key, Value]):
    def __init__(self, key: Key, value: Value) -> None:
        self.key: Key = key
        self.value: Value = value

    def first(self) -> Key:
        return self.key

    def second(self) -> Value:
        return self.value

class Holder(Generic[_Inner, T]):
    def __init__(self, inner: _Inner, other: T) -> None:
        self.inner: _Inner = inner
        self.other: T = other

    def unwrap(self) -> _Inner:
        return self.inner

b: Box[int] = Box(7)
print(b.get())
p: Pair[str, int] = Pair('a', 1)
print(p.first())
print(p.second())
h: Holder[str, int] = Holder('in', 3)
print(h.unwrap())
