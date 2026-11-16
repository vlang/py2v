class Stack:
    def __init__(self) -> None:
        self.stack = []
        self.names = {}
        self.rows = []

    def push(self, x: int) -> None:
        self.stack.append(x)

    def tag(self, name: str, n: int) -> None:
        self.names[name] = n

    def add_row(self, row: list[float]) -> None:
        self.rows.append(row)

    def pop(self) -> int:
        return self.stack.pop()

    def clear(self) -> None:
        self.stack = []
        self.names = {}


s = Stack()
s.push(3)
s.push(4)
s.tag("a", 1)
s.add_row([1.5, 2.5])
print(s.pop())
print(s.stack)
print(len(s.stack))
print(s.names)
print(s.rows)
s.clear()
print(s.stack)
print(len(s.names))
