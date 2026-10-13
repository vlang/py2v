from pkg_multi.sub.calc import Accumulator, twice


def run(n: int) -> int:
    acc = Accumulator(1)
    return acc.add(twice(n))
