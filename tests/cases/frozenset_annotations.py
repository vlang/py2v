def count(values: frozenset[str]) -> int:
    return len(values)


def contains(values: frozenset[str], name: str) -> bool:
    return name in values


def nonempty(values: frozenset) -> bool:
    return bool(values)


def build() -> frozenset[str]:
    return frozenset(["red", "blue", "red"])


def show() -> None:
    values: frozenset[str] = build()
    print(count(values), contains(values, "red"), contains(values, "green"))
    alias = values.copy()
    print(len(alias), alias == values, nonempty(alias))
    try:
        values.add("new")
    except AttributeError:
        print("immutable")


if __name__ == "__main__":
    show()
