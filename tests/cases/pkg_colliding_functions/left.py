from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from typing_extensions import override
else:
    def override(value: int) -> int:
        return value + 1


def keep_local(override: int) -> int:
    return override


def read() -> int:
    return keep_local(override(2))
