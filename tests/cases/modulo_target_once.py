class Counter:
    value: int

    def __init__(self, value: int):
        self.value = value


def index() -> int:
    print("index")
    return 0


def divisor() -> int:
    print("divisor")
    return 3


def main():
    values = [-7]
    values[index()] %= divisor()
    print(values)
    obj = Counter(-7)
    obj.value %= divisor()
    print(obj.value)


if __name__ == "__main__":
    main()
