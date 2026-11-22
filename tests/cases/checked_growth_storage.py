class Counter:
    def __init__(self):
        self.total = 1

    def grow(self):
        for i in range(5):
            self.total = self.total + self.total


item = Counter()
item.grow()
print(item.total)

values = [1]
for i in range(5):
    values[0] = values[0] + values[0]
print(values[0])
