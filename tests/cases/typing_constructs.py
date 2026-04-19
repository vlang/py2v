from typing import Union, Callable, Optional

def process(x: Union[int, str]) -> Optional[str]:
    return str(x)

def apply(f: Callable[[int], str], x: int) -> str:
    return f(x)

def maybe(x: int | None) -> str:
    return str(x)

result = process(42)
print(result)

