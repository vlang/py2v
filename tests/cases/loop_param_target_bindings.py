import asyncio


def discard_then_loop(pair: list[int]) -> int:
    x, _ = pair
    for _ in range(3):
        x += 1
    return x


def nested_try_match_while() -> int:
    total = 0
    for x in [1, 2]:
        try:
            for x in [10, 20]:
                pass
        finally:
            pass
        total += x
    return total


def nonlocal_loop_read() -> int:
    x = 0

    def bump() -> None:
        nonlocal x
        x = 99

    for x in [1, 2]:
        bump()
        print(x)
    return x


class InitLoopBox:
    tag: int = 0

    def __init__(self, rows: list[int]):
        for rows in [[1, 2, 3], [4, 5]]:
            pass
        self.tag = len(rows)


def walrus_and_loop_param(flag: bool, x: int) -> int:
    if flag and (x := 10) > 0:
        pass
    for x in [4, 5]:
        pass
    return x


def tuple_pair_rebind() -> int:
    a, b = 0, 0
    for a, b in [(1, 2), (3, 4)]:
        pass
    total = a + b
    for _, b in [(5, 6), (7, 8)]:
        total += b
    return total


def tuple_pair_strings() -> str:
    out = ""
    for a, b in ["xy", "zw"]:
        out += b + a
    return out


def closure_struct_rebind() -> int:
    def inner(box: InitLoopBox) -> int:
        box.tag = 5
        try:
            for box in [InitLoopBox([1]), InitLoopBox([1, 2, 3])]:
                pass
        finally:
            pass
        return box.tag

    orig = InitLoopBox([9])
    return inner(orig) * 10 + orig.tag


async def values():
    yield 10
    yield 20


async def main() -> None:
    print(discard_then_loop([10, 20]))
    print(nested_try_match_while())
    print(nonlocal_loop_read())
    orig = [9]
    print(InitLoopBox(orig).tag, orig)
    print(walrus_and_loop_param(True, 1), walrus_and_loop_param(False, 1))
    print(tuple_pair_rebind())
    print(tuple_pair_strings())
    print(closure_struct_rebind())
    item = 0
    async for item in values():
        pass
    print(item)


asyncio.run(main())
