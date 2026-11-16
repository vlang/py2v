#!/usr/bin/env python3


def show(small: dict[str, int], big: dict[str, int], rank: int) -> None:
    print(all(big[k] >= v for k, v in small.items()))
    print([k for k, v in small.items() if v == rank])
    print({k: v * 2 for k, v in small.items()})
    print(sum(v for v in small.values()))
    print(sorted(k for k in big if k not in small))
    print(any(v > 1 for _, v in big.items()))
    names = [k + str(v) for k, v in big.items() if v > 0 if k != "z"]
    print(len(names), names)
    grid = [x * y for x in [1, 2] for y in [10, 20]]
    print(grid)
    total = sum(n * w for n, w in zip([1, 2, 3], [4, 5, 6]))
    print(total)
    print(", ".join(f"{k}={v}" for k, v in small.items()))


if __name__ == "__main__":
    show({"a": 1, "b": 2}, {"a": 1, "b": 3, "c": 0}, 2)
