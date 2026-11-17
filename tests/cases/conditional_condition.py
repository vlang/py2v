def choose(a: bool, b: bool, c: bool) -> int:
    if a if c else b:
        return 3
    return 7


if __name__ == "__main__":
    print(choose(True, False, True))
    print(choose(True, False, False))
