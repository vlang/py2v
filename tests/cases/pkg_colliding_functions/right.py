from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from typing_extensions import override
else:
    def override(value: int) -> int:
        return value * 2


def read() -> int:
    return override(2)
