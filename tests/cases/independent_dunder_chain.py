class Score:
    def __lt__(self, other: "Score") -> bool:
        return False

    def __le__(self, other: "Score") -> bool:
        return True


def compare(a: Score, b: Score, c: Score) -> bool:
    return a <= b <= c
