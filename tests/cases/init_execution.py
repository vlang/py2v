def py2v_new_box() -> int:
    return 99


class Box:
    def __init__(self, a: int, b: int) -> None:
        self.total = a + b
        self.label = "box"


class Defaulted:
    def __init__(self, a: int, b: int = 7, label: str = "default") -> None:
        self.a: int = a
        self.b: int = b
        self.label: str = label


class CallsMethod:
    def __init__(self, amount: int) -> None:
        self.value: int = 0
        self.add(amount)

    def add(self, amount: int) -> None:
        self.value += amount


class ConstructsAnother:
    def __init__(self, a: int, b: int) -> None:
        inner = Box(a, b)
        self.total: int = inner.total


class Zero:
    def __init__(self) -> None:
        self.value = 7


class Base:
    def __init__(self, value: int) -> None:
        self.value: int = value


class Child(Base):
    def __init__(self, value: int, extra: int = 2) -> None:
        super().__init__(value)
        self.extra: int = extra


class PlainChild(Base):
    pass


class Plain:
    value: int = 17


def mark(value: int) -> int:
    print(value)
    return value


def ordered_calls() -> None:
    start = 4
    positional = Defaulted(mark(start), mark(start + 1), label="positional")
    print(positional.a, positional.b, positional.label)
    keyword = Defaulted(b=mark(start + 2), a=mark(start + 3), label="keyword")
    print(keyword.a, keyword.b, keyword.label)


b = Box(2, 3)
print(b.total, b.label)
d = Defaulted(2)
print(d.a, d.b, d.label)
k = Defaulted(label="named", a=3, b=8)
print(k.a, k.b, k.label)
m = CallsMethod(9)
print(m.value)
n = ConstructsAnother(4, 5)
print(n.total)
z = Zero()
print(z.value)
c = Child(10)
print(c.value, c.extra)
inherited = PlainChild(11)
print(inherited.value)
p = Plain()
print(p.value)
print(py2v_new_box())
ordered_calls()
