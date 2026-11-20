class Point:
    x: int

    def __init__(self, x: int) -> None:
        self.x = x

    def value(self) -> int:
        return self.x

    @staticmethod
    def origin_x() -> int:
        return 3
