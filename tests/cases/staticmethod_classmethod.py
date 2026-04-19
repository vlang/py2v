class MathHelper:
    def __init__(self, value: int):
        self.value = value

    @staticmethod
    def add(a: int, b: int) -> int:
        return a + b

    @classmethod
    def create(cls, v: int) -> 'MathHelper':
        return MathHelper(v)

    def double(self) -> int:
        return self.value * 2


result = MathHelper.add(3, 4)
obj = MathHelper.create(10)
print(result)

