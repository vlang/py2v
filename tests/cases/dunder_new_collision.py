class Item:
    def __new__(cls: int, value: int) -> int:
        return value + 2

    def new(self, value: int) -> int:
        return value + 1


def call_new(item: Item, value: int) -> int:
    return item.new(value)


def call_allocator(item: Item, value: int) -> int:
    return item.__new__(0, value)


print("loaded")
