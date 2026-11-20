def check(which: int) -> bool:
    print(which)
    return which == 2


if check(1):
    def choose(value: int) -> int:
        return value + 10
elif check(2):
    def choose(value: int) -> int:
        return value + 20
elif check(3):
    def choose(value: int) -> int:
        return value + 30
else:
    def choose(value: int) -> int:
        return value + 40


previous = choose
print(choose(1))
print(previous(2))
