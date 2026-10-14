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