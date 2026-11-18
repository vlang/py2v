def run() -> int:
    x = 3
    def inner(v: int = x) -> int:
        return v
    x = 11
    return inner()
print(run())
