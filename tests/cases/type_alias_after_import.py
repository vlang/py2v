import math

type Score = int


def bump(n: Score) -> Score:
    return n + int(math.sqrt(4))


def main() -> None:
    print(bump(5))


if __name__ == "__main__":
    main()
