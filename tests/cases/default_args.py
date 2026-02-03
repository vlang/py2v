def greet(name: str, greeting: str = "Hello") -> str:
    return greeting + ", " + name + "!"


def add(a: int, b: int = 10) -> int:
    return a + b


def main():
    print(greet("Alice"))
    print(greet("Bob", "Hi"))
    print(add(5))
    print(add(5, 20))


if __name__ == "__main__":
    main()
