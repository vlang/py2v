class Holder:
    values: list[int]

    def __init__(self, values: list[int]):
        self.values = values

    def add(self, value: int) -> None:
        self.values.append(value)


def main():
    a = [1, 2]
    holder = Holder(a)
    holder.add(3)
    print(a, holder.values)
    a.append(4)
    print(holder.values)


if __name__ == "__main__":
    main()
