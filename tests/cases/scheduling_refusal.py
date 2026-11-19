from asyncio import Future, run_coroutine_threadsafe as submit


async def answer() -> int:
    return 7


def read_future(loop) -> int:
    with open(__file__):
        future = submit(answer(), loop)
    return future.result()


class Runner:
    async def wait(self, future) -> int:
        return await future


def supported() -> int:
    return 42


def annotation_only(value: Future[int]) -> int:
    return 9


print(supported())
print(annotation_only(None))
