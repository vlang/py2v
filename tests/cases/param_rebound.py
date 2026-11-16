def countdown(n: int) -> int:
    steps = 0
    while n > 0:
        n -= 1
        steps += 1
    return steps


def shout(text: str, times: int) -> str:
    text = text.upper()
    while times > 1:
        text += "!"
        times -= 1
    return text


def clamp(x: float, lo: float = 0.0) -> float:
    if x < lo:
        x = lo
    return x


class Counter:
    def __init__(self) -> None:
        self.total: int = 0

    def add(self, amount: int) -> int:
        if amount < 0:
            amount = 0
        self.total += amount
        return self.total


value = 3
print(countdown(value))
print(value)
print(shout("hi", 3))
print(clamp(-1.5))
print(clamp(2.5))
c = Counter()
print(c.add(-4))
print(c.add(5))
