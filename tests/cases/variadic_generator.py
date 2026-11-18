import asyncio


async def values(first: int, *remaining: int):
    yield first
    for item in remaining:
        yield item


async def show():
    async for item in values(1):
        print(item)
    async for item in values(2, 3, 4):
        print(item)


if __name__ == "__main__":
    asyncio.run(show())
