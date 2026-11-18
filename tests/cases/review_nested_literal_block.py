def run() -> int:
    if True:
        def inner(v: int = 9) -> int:
            return v
    return inner()
print(run())
