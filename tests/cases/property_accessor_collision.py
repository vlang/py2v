class Box:
    def __init__(self):
        self._value: int = 0

    @property
    def value(self) -> int:
        return self._value

    @value.setter
    def value(self, assigned: int):
        self.set_value(assigned + 1)

    @value.deleter
    def value(self):
        self._value = -1

    def set_value(self, assigned: int):
        self._value = 2 * assigned


def assigned_value() -> int:
    print("assign")
    return 3


box = Box()
box.value = assigned_value()
print(box.value)
box.set_value(5)
print(box.value)
del box.value
print(box.value)
