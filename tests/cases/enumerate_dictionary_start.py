def keys() -> dict[str, int]:
    print("iterable")
    return {"alpha": 1, "beta": 2}


def offset() -> int:
    print("start")
    return -3


for index, key in enumerate(keys(), start=offset()):
    print(index, key)
for index, key in enumerate({"one": 1, "two": 2}):
    print(index, key)
for index, key in enumerate(["yes", "no"], start=True):
    print(index, key)
