from __future__ import annotations
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .item import Item as Model


def same(value: Model) -> int:
    return value.value
