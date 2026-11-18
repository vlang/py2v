import pkg_imports.values as source
from .values import LOCAL_OFFSET as local_alias
from .sub.values import REMOTE_OFFSET as remote_alias
import pkg_imports.sub.values as remote
from .values import _SHARED_LIMIT as first_limit
from .other_values import _SHARED_LIMIT as second_limit


def imported_values_total() -> int:
    return (source.LOCAL_OFFSET + local_alias + remote_alias
            + remote.REMOTE_OFFSET + first_limit + second_limit)
