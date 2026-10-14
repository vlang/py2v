from . import leaf
from .leaf import leaf_value
from ..helpers import alpha
from ..sibling import shout


def relative_total() -> int:
    return alpha() + leaf_value() + leaf.leaf_value()


def parent_total() -> str:
    return shout()
