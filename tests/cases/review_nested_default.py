def run() -> int:
    x = 3
    def inner(v: int = x) -> int:
        return v
    return inner()
print(run())
