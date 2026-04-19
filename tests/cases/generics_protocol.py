from typing import TypeVar, Generic, Protocol

T = TypeVar('T')


class Stack(Generic[T]):
    def __init__(self) -> None:
        self.items: list[T] = []

    def push(self, item: T) -> None:
        self.items.append(item)

    def pop(self) -> T:
        return self.items.pop()

    def is_empty(self) -> bool:
        return len(self.items) == 0


class Sized(Protocol):
    def __len__(self) -> int: ...


def first(stack: Stack[T]) -> T:
    return stack.pop()


s: Stack[int] = Stack()
s.push(1)
s.push(2)
print(s.pop())

