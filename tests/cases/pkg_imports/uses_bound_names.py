import pkg_imports.helpers as helper_module
import pkg_imports.sub.leaf as leaf_module
import pkg_imports.sub.leaf
from .helpers import alpha as first
from .sub.leaf import leaf_value as last
from .sub import leaf as submodule


def bound_names_total() -> int:
    return (helper_module.alpha() + leaf_module.leaf_value()
            + pkg_imports.sub.leaf.leaf_value() + first() + last()
            + submodule.leaf_value())


def shadow_module(helper_module: int) -> int:
    return helper_module + 1


def shadow_import() -> int:
    last = 4
    return last
