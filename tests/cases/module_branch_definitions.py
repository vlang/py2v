def option() -> bool:
    print("select")
    return False


if option():
    def choose(value: int) -> int:
        return value + 1

    def offset() -> int:
        return 10
else:
    def choose(value: int) -> int:
        return value + 2

    def offset() -> int:
        return 20


def use(value: int) -> int:
    return choose(value) + offset()


saved = choose
print(saved(5), use(6))
