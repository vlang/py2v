import asyncio


def note(value: int) -> int:
    print("eval", value)
    return value


async def values(first: int = 2, *remaining: int, bonus: int = 4):
    yield first + bonus
    for item in remaining:
        yield item + bonus


async def show():
    async for item in values(note(1), note(2), bonus=note(3)):
        print(item)
    async for item in values(bonus=6):
        print(item)


if __name__ == "__main__":
    asyncio.run(show())
