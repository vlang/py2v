from typing import TypeAlias
BB: TypeAlias = int
HIGH: BB = 1 << 63
items = [HIGH]
items.append(-1)
print(items[0])
print(items[1])
