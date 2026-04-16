#!/usr/bin/env python3
from dataclasses import dataclass
@dataclass
class Point:
    x: float
    y: float
    label: str = "origin"
@dataclass
class Circle:
    center: Point
    radius: float = 1.0
def show():
    p = Point(1.5, 2.5)
    print(p.x)
    print(p.label)
    c = Circle(p, 3.0)
    print(c.radius)
if __name__ == "__main__":
    show()
