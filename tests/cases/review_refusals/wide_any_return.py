from typing import Any, TypeAlias
BB: TypeAlias = int
HIGH: BB = 1 << 63
def f() -> Any:
    return HIGH
print(f())
