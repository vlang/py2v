def text() -> str:
    print("read")
    return ""


def missing(s: str) -> bool:
    return s == None


print(missing(""))
print(not missing(text()))
values = ["", "x"]
print(missing(values[1]))
