from typing import Any, TypeAlias
BB: TypeAlias = int
HIGH: BB = 1 << 63
items: list[Any] = [HIGH]
items.append(-1)
print(items[0])
print(items[1])
