def forward() -> int:
    def read() -> int:
        return value + 1

    value = 4
    return read()


def loop() -> int:
    for value in range(2):
        def read() -> int:
            return value + 2
        result = read()
    return result


def default(n: int) -> int:
    def read(x: int = n + 1) -> int:
        return x + 3
    return read()


def rebound_function() -> int:
    callback = lambda: 1

    def read() -> int:
        return callback()

    callback = lambda: 2
    return read()
