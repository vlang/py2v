from pathlib import Path

class Box:
    r: int
    def __init__(self, n: int):
        self.r = n

class Reader:
    def r(self) -> int:
        return 3

def f(x: int, y: int = 10) -> int:
    return x + y

def main() -> None:
    r_tail = 10
    tr = 20
    print([r.strip() for r in [" r "]])
    print([r + r_tail + tr for r in [1, 2]])
    print(["r" for r in [1]])
    print([f"r={r}" for r in [1, 2]])
    print([r.r for r in [Box(3)]])
    x = Box(4)
    print([x.r + r for r in [1, 2]])
    print([r.r() for r in [Reader()]])
    print([r for r in [1, 2] if r >= len("r")])
    print([fn for fn in [1, 2]])
    print([type for type in [1, 2] if type > 1])
    print([match for match in [1, 2]])
    print([[1 for a, *a_part in [[a, *a_part]]] for a, *a_part in [[2, 5, 7]]])
    print([f(2) for f in [f]])
    p = Path("a/b.txt")
    paths = [Path("x/y.txt")]
    print(p.name)
    print([p.name for p in paths])
    print({s: len([r for r in [1, 2] if r >= len("r")]) for s in [2]})

if __name__ == "__main__":
    main()
