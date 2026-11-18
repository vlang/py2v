from __future__ import annotations
from typing import TYPE_CHECKING as CHECK

if CHECK:
    from ..model import Item as Model
    from ..model import item as schemas
    from missing_type_only_dependency import Opaque

if True:
    if CHECK:
        from missing_type_only_dependency import Nested


class Holder:
    item: Model


def take(value: Model) -> int:
    return value.value


def size(values: list[Model]) -> int:
    return len(values)


def named(value: "schemas.Item") -> int:
    return value.value


def opaque(value: Opaque) -> int:
    return 5


def nested(value: Nested) -> int:
    return 6
