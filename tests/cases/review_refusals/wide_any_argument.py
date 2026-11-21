from typing import Any, TypeAlias
BB: TypeAlias = int
HIGH: BB = 1 << 63
def show(x: Any) -> None:
    print(x)
show(HIGH)
