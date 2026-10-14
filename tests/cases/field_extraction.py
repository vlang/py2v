class Slots:
    """Fields declared only through __slots__."""

    __slots__ = ("_name", "size")

    def __init__(self, _name: str):
        self._name = _name
        self.size = 0

    def bump(self, _name: str) -> str:
        # An attribute first assigned from a method other than __init__.
        self.size += 1
        return self._name


class Base:
    value: str

    def __init__(self, value):
        self.value = value


class Derived(Base):
    """Declares no fields of its own; the constructor delegates upward."""

    def __init__(self, value):
        super().__init__(value)

    def label(self) -> str:
        return self.value


class LateAssignment:
    """A slot declared before the annotation that types it."""

    __slots__ = ("count",)

    def __init__(self):
        self.count: int = 0

    def add(self, by: int) -> int:
        self.count += by
        return self.count


def use() -> int:
    s = Slots("a")
    d = Derived("b")
    l = LateAssignment()
    return s.size + l.add(1) + len(d.label())