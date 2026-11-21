from typing import Any, TypeAlias
BB: TypeAlias = int
HIGH: BB = 1 << 63
items: list[Any] = [HIGH]
print(items[0])
