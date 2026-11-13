def sub(*, a: int, b: int) -> int:
    return a - b


def main() -> None:
    print(sub(b=1, a=10))
    print(area(3, scale=10))
    print(negative(a=3))
    print(text(b="!"))
    print(descend(n=3))
    print(first(xs=[11]))


def area(w: int, h: int = 2, depth: int = 3, scale: int = 4) -> int:
    return w * h * depth * scale


def negative(a: int, b: int = -7) -> int:
    return a - b


def text(a: str = "it's", b: str = "ok") -> str:
    return a + b


def descend(n: int) -> int:
    if n == 0:
        return 0
    return 1 + descend(n=n - 1)


def first(xs: list[int]) -> int:
    return xs[0]


if __name__ == "__main__":
    main()
