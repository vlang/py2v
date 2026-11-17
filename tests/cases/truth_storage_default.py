def report(items: list = None) -> None:
    print(len(items or []))
    if items:
        print("items")
    print(not items)


if __name__ == "__main__":
    report([])
    report([1])
