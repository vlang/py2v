def names(count: int) -> "list[str]":
    return ["n" + str(i) for i in range(count)]


def lookup(key: str) -> "dict[str, int] | None":
    if key == "":
        return None
    return {key: len(key)}


def first(items: "list[str]") -> "str|None":
    if len(items) == 0:
        return None
    return items[0]


def pair(key: str) -> "tuple[str|None, int]":
    return key, len(key)


print(names(2))
print(lookup("abc") is None, lookup("") is None)
print(first(names(2)) is None, first([]) is None)
print(len(pair("ab")))
