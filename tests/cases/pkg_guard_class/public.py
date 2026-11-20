class ColorBox:
    def value(self) -> int:
        return 2


def read() -> int:
    return ColorBox().value()
