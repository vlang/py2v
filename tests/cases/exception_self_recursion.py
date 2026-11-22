class Counter:
    def walk(self, n: int) -> int:
        if n == 0:
            raise ValueError("bottom")
        return self.walk(n - 1)

    def go(self, n: int) -> int:
        if n == 0:
            raise ValueError("go-bottom")
        return self.go(n - 1)

    def leaf(self, n: int) -> int:
        if n == 0:
            raise ValueError("leaf")
        return n

    def through(self, n: int) -> int:
        return self.leaf(n)


counter = Counter()
try:
    counter.walk(2)
except ValueError as problem:
    print("recursive", str(problem))

try:
    print(counter.go(2))
except ValueError as problem:
    print("reserved", str(problem))

try:
    counter.through(0)
except ValueError as problem:
    print("through", str(problem))
