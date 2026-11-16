class Stack:
    def __init__(self):
        self.items = []

    def push(self, item):
        self.items.append(item)

    def push_pair(self, a: int, b: int):
        self.items.append([a, b])

    def size(self) -> int:
        return len(self.items)

    def show(self):
        print(self.items)
        print(self.items[0])


def mixed():
    items = []
    items.append(1)
    items.append("a")
    items.append([1, 2])
    items.append(2.5)
    return items


def main():
    empty = []
    print(len(empty))
    items = mixed()
    print(len(items))
    row = []
    row.append(7)
    row.append("seven")
    row.append([7, 7])
    print(len(row))
    print(row[0])
    print(row[1])
    for item in row:
        print(item)
    print(row)
    if row[0] == 7:
        print("first is seven")
    print(row[0] + 1)
    stack = Stack()
    stack.push(3)
    stack.push("three")
    stack.push_pair(3, 4)
    print(stack.size())
    stack.show()


if __name__ == "__main__":
    main()
