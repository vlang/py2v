from pkg_multi2.sub.core import Counter, scale


def run(n: int) -> int:
    c = Counter(1)
    return c.bump(scale(n))
