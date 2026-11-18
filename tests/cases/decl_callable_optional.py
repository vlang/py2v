from typing import Callable


class Handler:
    callback: Callable[[int], int] | None = None

    def run(self) -> int:
        return 3


print(Handler().run())
