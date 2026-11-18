from __future__ import annotations
import typing as hints

if hints.TYPE_CHECKING:
    from ..cycle_a.item import Unit


def answer(value: Unit) -> int:
    return 9
