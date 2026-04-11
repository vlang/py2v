#!/usr/bin/env python3

import asyncio


async def nested() -> int:
    return 7


async def show():
    a = await asyncio.create_task(nested())
    b = await asyncio.run(nested())
    assert a == 7
    assert b == 7


if __name__ == "__main__":
    asyncio.run(show())

