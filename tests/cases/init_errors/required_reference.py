class Child:
    def __init__(self, value: int) -> None:
        self.value: int = value


class Parent:
    def __init__(self) -> None:
        self.child: Child = Child(1)


p = Parent()
print(p.child.value)
