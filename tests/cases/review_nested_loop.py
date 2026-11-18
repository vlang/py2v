def run() -> int:
    for i in range(1):
        def inner() -> int:
            return 5
    return inner()
print(run())
