import asyncio


async def forward_consumer() -> None:
    async for item in forward_values(3, 4):
        print(item)


async def forward_values(*items: int):
    for item in items:
        yield item


async def colliding_channel(ch: int, *rest: int):
    yield ch
    for item in rest:
        yield item + ch


async def aliased_values(first: int, *remaining: int):
    yield first
    for item in remaining:
        yield item


def sync_variadic(first: int, *remaining: int):
    yield first
    for item in remaining:
        yield item


class Source:
    bias: int = 10

    async def values(self, first: int, *items: int, bonus: int = 2):
        yield first + bonus + self.bias
        for item in items:
            yield item + bonus + self.bias

    @staticmethod
    def static_values(*xs: int):
        for x in xs:
            yield x

    @classmethod
    def class_values(cls, *xs: int):
        for x in xs:
            yield x * 2


def with_nested_generator() -> list[int]:
    def producer(*xs: int):
        for x in xs:
            yield x * 5

    return list(producer(2, 3))


def void_with_nested_generator():
    def gen(n: int):
        yield n

    print(list(gen(3)))


async def show() -> None:
    await forward_consumer()
    async for item in colliding_channel(3, 4):
        print(item)
    gen = aliased_values
    async for item in gen(2, 3, 4):
        print(item)
    source = Source()
    async for item in source.values(1, 2, bonus=5):
        print(item)
    print(list(Source.static_values(3, 4)))
    print(list(Source.class_values(3, 4)))
    print(list(sync_variadic(2, 3, 4)))
    for v in sync_variadic(8, 9):
        print(v)
    print(with_nested_generator())
    void_with_nested_generator()


if __name__ == "__main__":
    asyncio.run(show())
