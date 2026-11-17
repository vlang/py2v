def collect() -> list[int]:
    values: list[int] = []
    push = values.append
    push(3)
    push(7)
    return values


if __name__ == "__main__":
    print(collect())
