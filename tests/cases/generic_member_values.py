from typing import Generic, TypeVar

ItemType = TypeVar("ItemType")
CountType = TypeVar("CountType")


class NamedCount(Generic[ItemType, CountType]):
    def __init__(self, label: ItemType, count: CountType) -> None:
        self.label: ItemType = label
        self.count: CountType = count

    def read_count(self) -> CountType:
        return self.count


def make(label: str, count: int) -> NamedCount[str, int]:
    return NamedCount(label, count)


first = make("first", 101)
second = make("second", -990)
print(second.read_count(), first.label, first.read_count(), second.label)
