from typing import overload


class Box:
    value: int

    @overload
    def __init__(self, value: int) -> None: ...

    def __init__(self, value: int) -> None:
        self.value = value

    @overload
    def __add__(self, other: "Box") -> "Box": ...

    @overload
    def __add__(self, other: int) -> "Box": ...

    def __add__(self, other: "Box") -> "Box":
        return Box(self.value + other.value)

    @overload
    def fetch(self, index: int) -> int: ...

    @overload
    def fetch(self, index: str) -> int: ...

    def fetch(self, index: int) -> int:
        return self.value + index


if __name__ == "__main__":
    box = Box(2)
    print(box.fetch(3))
    print((box + Box(4)).value)
