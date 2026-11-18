from outside import Parent


class Child(Parent):
    def value(self, x: int):
        result = super().make(x, limit=3)
        return result

    def stream(self):
        yield from super().stream()
