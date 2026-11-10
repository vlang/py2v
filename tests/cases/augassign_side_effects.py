def index(i: int) -> int:
    print(f"index {i}")
    return i


def key(k: str) -> str:
    print(f"key {k}")
    return k


def grow_rows(rows: list[list[int]]) -> int:
    print("grow rows")
    rows.append([5])
    return 0


def grow_tail(rows: list[list[int]]) -> int:
    print("grow tail")
    rows.append([7])
    return len(rows)


class Box:
    def __init__(self, size: int):
        self.size: int = size


class Two:
    def __add__(self, other: "Two") -> int:
        print("add")
        return 2


class Py2v:
    é_IDX17 = 17


def main():
    # **= and //= evaluate the index once, as Python does.
    # Each container gets a plain element store first only so that it is
    # declared mut; `x[i] **= v` alone does not mark it yet.
    nums: list[int] = [0, 8, 10]
    nums[0] = 3
    nums[index(0)] **= 2
    nums[index(1)] //= 3
    nums[-1] **= 2
    print(nums)

    # Nested indices are evaluated once each, left to right
    grid: list[list[int]] = [[1, 2], [3, 4]]
    grid[1] = [5, 6]
    grid[index(1)][index(0)] **= 2
    print(grid)

    # Slice bounds are evaluated once too, before the index that follows them
    grid[index(0):index(2)][index(1)][1] //= 2
    print(grid)

    # A negative index selects its row before a later index call changes the length
    rows: list[list[int]] = [[2], [3]]
    rows[0] = [2]
    rows[-1][grow_rows(rows)] **= 2
    print(rows)

    # An index inside an attribute target
    boxes: list[Box] = [Box(1)]
    boxes[0] = Box(3)
    boxes[index(0)].size **= 2
    print(boxes[0].size)

    # A computed dict key
    counts: dict[str, int] = {"a": 9}
    counts["a"] = 10
    counts[key("a")] //= 3
    print(counts["a"])

    # A negative slice bound counts from the end once both bounds are evaluated,
    # so it sees the row grow_tail appends. The temps skip py2v_idx12, which the
    # source already uses.
    py2v_idx12 = 17
    tail: list[list[int]] = [[2], [3]]
    tail[0] = [2]
    tail[-1:grow_tail(tail)][0][0] **= 2
    print(tail)
    print(py2v_idx12)

    # `two + two` calls Two.__add__, which could change `i`, so the index is
    # read before it; `i + 1` on ints runs no code and leaves the target as is.
    i = 0
    two = Two()
    nums[i] **= two + two
    nums[i] //= i + 1
    print(nums)
    scale(5)


def scale(PY2V_IDX16: int) -> None:
    # py2v writes the parameter as py2v_idx16 and the class constant as
    # py2v_idx17 (the frontend's JSON escapes the é), so the temp skips both
    vals: list[int] = [8, 9]
    vals[0] = 8
    vals[index(1)] //= PY2V_IDX16
    print(vals)
    print(PY2V_IDX16)
    print(Py2v.é_IDX17)


if __name__ == "__main__":
    main()
