class Point:
    def __init__(self, x: int, y: int = 20) -> None:
        self.x: int = x
        self.y: int = y


class Tag:
    def __init__(self, name: str) -> None:
        self.name: str = name


class Plain:
    value: int = 17
