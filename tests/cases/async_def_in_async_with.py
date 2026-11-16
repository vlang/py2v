import asyncio
import contextlib


async def outer() -> int:
    async with contextlib.AsyncExitStack():
        base = 5

        async def double(x: int) -> int:
            return (x + base) * 2

        return await double(1)


print(asyncio.run(outer()))
