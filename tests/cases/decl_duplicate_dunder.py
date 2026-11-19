class Sample:
    def contains(self, value: int) -> bool:
        return value == 1

    def __contains__(self, value: int) -> bool:
        return value == 2

    def index(self, value: int) -> int:
        return value + 1

    def __getitem__(self, value: int) -> int:
        return value + 2

    def repr(self) -> str:
        return "ordinary"

    def __repr__(self) -> str:
        return "dunder"

    def to_int(self) -> int:
        return 3

    def __int__(self) -> int:
        return 4


sample = Sample()
print(sample.contains(1))
print(sample.__contains__(2))
print(sample.index(1))
print(sample.__getitem__(1))
print(sample.repr())
print(sample.__repr__())
print(sample.to_int())
print(sample.__int__())
