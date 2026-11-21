def index(values: list[str], target: str) -> int:
    return values.index(target)

def piece_index(target: str) -> int:
    pieces = [None, "p", "n"]
    return pieces.index(target)

if __name__ == "__main__":
    print(index(["r", "q", "r"], "r"))
    print(piece_index("n"))
    try:
        print(index(["r", "q"], "x"))
    except ValueError:
        print("missing")
