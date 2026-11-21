from typing import TypeAlias, Any, Callable
BB: TypeAlias = int
HIGH: BB = 1 << 63

def use(f: Callable[[Any], None]) -> None:
    f(HIGH)

def show(x: Any) -> None:
    print(x)

use(show)
