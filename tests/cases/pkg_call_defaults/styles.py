from typing import Any
from mypy_extensions import mypyc_attr as metadata


def print_style(key: str, value: Any) -> None:
    print(key, value)


@metadata(patchable=True)
def styled(message: str = "default", *, newline: bool = True, **styles: Any) -> None:
    print(message, newline)
    for key, value in styles.items():
        print_style(key, value)
