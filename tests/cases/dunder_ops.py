class Vector:
    def __init__(self, x: int, y: int):
        self.x = x
        self.y = y

    def __add__(self, other: 'Vector') -> 'Vector':
        return Vector(self.x + other.x, self.y + other.y)

    def __eq__(self, other: 'Vector') -> bool:
        return self.x == other.x and self.y == other.y

    def __str__(self) -> str:
        return f'Vector({self.x}, {self.y})'

    def __repr__(self) -> str:
        return f'Vector({self.x}, {self.y})'

    def __len__(self) -> int:
        return 2

    def __neg__(self) -> 'Vector':
        return Vector(-self.x, -self.y)


v1 = Vector(1, 2)
v2 = Vector(3, 4)
v3 = v1 + v2
print(v3)



class _Private:
    def __init__(self, tag: str):
        self.tag = tag

    def label(self) -> str:
        return self.tag


def describe(p: _Private) -> str:
    return repr(p) + str(p)
