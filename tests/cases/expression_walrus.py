def collect() -> list[int]:
    index = 0
    spans = [index, (index := index + 1), index]
    spans.append((index := index + 2))
    print(index)
    return spans


if __name__ == "__main__":
    print(collect())
