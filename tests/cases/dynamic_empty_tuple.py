from typing import Any


def read(values: Any) -> Any:
    return values.get("items", ())


print(read({"items": 5}))
print(read({}))
