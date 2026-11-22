class Stub:
    def marker(self) -> int:
        return 1


stub = Stub()
if stub.marker() != 1:
    print("stub marker failed")


def evaluate(a: int, b: int = 7) -> int:
    if a < 0:
        raise ValueError("bad")
    return a * 100 + b


def effect(label: str, value: int) -> int:
    print(label)
    return value


try:
    print(evaluate(a=effect("A", 1), b=effect("B", 2)))
except ValueError:
    print("caught")
