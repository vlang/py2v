class Cipher:
    def __init__(self, key: int = 0):
        self.key = key

    def shift(self, value: int, key: int) -> int:
        key = key or self.key or 1
        return value + key


def greeting(given: str) -> str:
    name = given or "world"
    return "hello " + name


def first_items(given: list[int]) -> list[int]:
    items = given or [0]
    return items


def both(a: int, b: int) -> int:
    return a and b


def neither(a: int, b: int) -> bool:
    return not (a and b)


def main():
    print(greeting(""))
    print(greeting("you"))
    print(Cipher().shift(1, 0))
    print(Cipher(5).shift(1, 0))
    print(Cipher(5).shift(1, 2))
    print(len(first_items([])))
    print(len(first_items([4, 5])))
    print(both(0, 3))
    print(both(2, 3))
    print(neither(1, 1))
    print(neither(1, 0))


if __name__ == "__main__":
    main()
