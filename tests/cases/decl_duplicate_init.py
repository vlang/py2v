class Counter:
    def __init__(self, value: int):
        self.value = value

    def init(self, value: int):
        self.value = value + 1


counter = Counter(3)
print(counter.value)
counter.init(5)
print(counter.value)
