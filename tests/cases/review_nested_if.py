def run() -> int:
    if True:
        def inner() -> int:
            return 4
    return inner()
print(run())
