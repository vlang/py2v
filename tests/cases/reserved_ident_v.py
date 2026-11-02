class Holder:
    def __init__(self, v: int):
        self.v = v

    def bump(self, v: int) -> int:
        self.v = v
        return self.v


def local_use() -> int:
    v = Holder(1)
    return v.v + v.bump(2)


def param_use(v: int) -> int:
    return v + 1


def comprehension(rows: list[list[int]]) -> list[str]:
    return [f"{v}" for row in rows for v in row]

def spawn(x: int) -> int:
    return x * 2


def exit(x: int) -> int:
    return x - 1


def malloc(n: int) -> list:
    return [0] * n


def free(p: list) -> int:
    return len(p)


print(spawn(21))
print(exit(3))
print(free(malloc(4)))
