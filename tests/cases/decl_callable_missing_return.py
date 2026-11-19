from __future__ import annotations
from typing import Callable


class Handler:
    callback: Callable[[int]]

    def run(self) -> int:
        return 3


print(Handler().run())
