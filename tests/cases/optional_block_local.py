def promotion(use_piece: bool, symbol: str) -> int | None:
    try:
        selected = ["n", "b"].index(symbol) if use_piece else None
    except ValueError:
        return None
    return selected

if __name__ == "__main__":
    chosen = promotion(True, "b")
    if chosen is not None:
        print(chosen)
    print(promotion(False, "b") is None)
    print(promotion(True, "x") is None)
