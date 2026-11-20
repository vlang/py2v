from . import left as coordinates
from .left import Point as Coordinate
from .right import Point as Label


class Shifted(Coordinate):
    def __init__(self, x: int) -> None:
        super().__init__(x)

    def shifted(self) -> int:
        return self.value() + 1


class Box:
    points: list[Coordinate]


def keep(point: Coordinate) -> Coordinate:
    return point


def total() -> str:
    origin = coordinates.Point(Coordinate.origin_x())
    shifted = Shifted(5)
    label = Label(Label.tagged("point"))
    if not isinstance(origin, Coordinate):
        return "wrong Coordinate"
    if isinstance(origin, Label):
        return "wrong Label"
    return label.text() + " " + str(keep(origin).value()) + " " + str(shifted.shifted())
