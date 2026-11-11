class Point:
    def __init__(self, x: int) -> None:
        self.x: int = x


class Box:
    def __init__(self, items: list[int]) -> None:
        self.items: list[int] = items

    def put(self) -> None:
        self.items[0] = 5

    def bump(self) -> None:
        self.items[1] += 5


def main():
    a: list[int] = [1, 2]
    a[0] += 1
    print(a)

    counts: dict[str, int] = {"x": 1}
    counts["x"] += 1
    print(counts["x"])

    grid: list[list[int]] = [[1, 2], [3, 4]]
    grid[0][1] = 5
    grid[1][0] *= 3
    print(grid)

    b = Box([1, 2])
    b.put()
    b.bump()
    print(b.items)

    points: list[Point] = [Point(1), Point(2)]
    points[0].x = 7
    print(points[0].x)

    lists: dict[str, list[int]] = {"a": [1, 2]}
    lists["a"][1] = 9
    print(lists["a"])


if __name__ == "__main__":
    main()
