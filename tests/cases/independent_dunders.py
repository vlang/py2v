class Number:
    value: int

    def __init__(self, value: int):
        self.value = value

    def __eq__(self, other: "Number") -> bool:
        return self.value == other.value

    def __lt__(self, other: "Number") -> bool:
        return self.value < other.value

    def __ne__(self, other: "Number") -> bool:
        return self.value == other.value

    def __le__(self, other: "Number") -> bool:
        return self.value < other.value

    def __gt__(self, other: "Number") -> bool:
        return self.value < other.value

    def __ge__(self, other: "Number") -> bool:
        return self.value < other.value

    def __truediv__(self, other: "Number") -> "Number":
        return Number(self.value + other.value)

    def __floordiv__(self, other: "Number") -> int:
        return self.value // other.value

    def __add__(self, other: "Number") -> "Number":
        return Number(self.value + other.value)

    def __pos__(self) -> int:
        return self.value + 10

    def __sub__(self, other: "Number") -> "Number":
        return Number(self.value - other.value)

    def __neg__(self) -> int:
        return 10 - self.value

    def __invert__(self) -> int:
        return self.value + 20


def check(a: Number, b: Number):
    print(a != b)
    print(a <= b)
    print(a > b)
    print(a >= b)
    print(a // b)
    print(-a)
    print(+a)
    print(~a)
    print(a.__ne__(b))


if __name__ == "__main__":
    check(Number(5), Number(2))
