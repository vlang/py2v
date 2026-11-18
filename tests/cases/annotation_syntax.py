from typing import ClassVar, Final


class Settings:
    labels: ClassVar[list[str]] = ["left", "right"]
    kind: ClassVar[type[int]] = int
    limit: Final[int] = 3


def sentinel_map(values: dict[str, None]) -> dict[str, None]:
    return values


def class_argument(factory: type[int]):
    return factory(3)
