from typing import TYPE_CHECKING
if TYPE_CHECKING:
    parts = [{'x': 1}]
    merged = {**part for part in parts}
print('ok')
