from typing import Any, TypeAlias
BB: TypeAlias = int
HIGH: BB = 1 << 63
def f(values: list[Any]) -> None:
    print(values[0])
f([HIGH])
