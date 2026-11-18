def show() -> None:
    values = set()
    alias = values
    print(len(values), bool(values))
    values.add(True)
    values.add(1)
    values.add(2)
    print(len(alias), 1 in alias, 3 in alias)
    alias.discard(1)
    print(len(values), 2 in values)
    values.clear()
    print(len(alias))
    values = set()
    values.add("new")
    print(len(values), len(alias))
    annotated: set[int] = set()
    annotated.add(4)
    print(4 in annotated, 5 in annotated)
    try:
        values.add([])
    except TypeError:
        print("caught")
    print(len(values))


if __name__ == "__main__":
    show()
