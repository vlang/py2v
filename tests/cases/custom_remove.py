class Leaf:
    def __init__(self, value: int) -> None:
        self.value = value

    def remove(self) -> int:
        self.value += 1
        return self.value


def main() -> None:
    leaf = Leaf(3)
    first = leaf.remove()
    leaf.remove()
    print(first)
    print(leaf.value)


if __name__ == "__main__":
    main()
