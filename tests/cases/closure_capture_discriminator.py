def outer(_type: int, name: int, annotation: int) -> int:
    def inner() -> int:
        return _type + name + annotation
    return inner()


if __name__ == "__main__":
    print(outer(10, 20, 12))
