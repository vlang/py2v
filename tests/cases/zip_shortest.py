def first() -> list[int]:
    print("first")
    return [1, 2, 3]


def second() -> list[str]:
    print("second")
    return ["a", "b"]


for a, b in zip(first(), second()):
    print(f"{a}:{b}")

for text, number in zip(second(), first()):
    print(f"{text}:{number}")

for character, number in zip("é🙂", [1, 2, 3]):
    print(f"{character}:{number}")
