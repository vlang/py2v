def in_unit(v: float) -> bool:
    return 0.0 <= v < 1.0


def between(lo: int, x: int, hi: int) -> bool:
    return lo < x <= hi


def ascending(a: int, b: int, c: int, d: int) -> bool:
    return a < b < c < d


def bump(counter: list[int]) -> int:
    counter[0] += 1
    return counter[0]


def main() -> None:
    print(in_unit(0.5))
    print(in_unit(1.5))
    print(in_unit(-0.5))
    print(between(1, 5, 10))
    print(between(1, 11, 10))
    print(between(1, 1, 10))
    print(ascending(1, 2, 3, 4))
    print(ascending(1, 2, 3, 3))
    print(ascending(1, 3, 2, 4))
    xs = [3, 7, 9]
    i = 1
    if 0 <= i < len(xs):
        print("index ok")
    if 5 < xs[i] < 7:
        print("not printed")
    if 5 < xs[i] == 7:
        print("seven")
    n = 20
    for _ in range(50):
        if 10 < n < 23:
            n += 1
    print(n)
    counter = [0]
    if 0 < bump(counter) < 5:
        print("bumped once")
    print(counter[0])
    ok = 1 <= len(xs) <= 3
    print(ok)


if __name__ == "__main__":
    main()
