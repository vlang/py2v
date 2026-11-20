try:
    from .available import value

    def pick() -> int:
        return value()
except ImportError:
    def pick() -> int:
        return -1


try:
    from .available import value as other_value
except ImportError:
    class Label:
        def text(self) -> str:
            return "absent"
else:
    class Label:
        def text(self) -> str:
            return "present"


def total() -> str:
    return str(pick() + other_value()) + " " + Label().text()
