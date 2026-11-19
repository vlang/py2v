FILES = ["a", "b"]
RANKS = ["1", "2"]
SQUARES = [file + rank for rank in RANKS for file in FILES]


def total() -> str:
    return " ".join(SQUARES)
