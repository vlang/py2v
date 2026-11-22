def components(chroma: float, value: float) -> list[float]:
    saturation = 0 if value == 0 else chroma / value
    return [value, saturation]


def selected_saturation(chroma: float, value: float, zero: int = 0) -> float:
    return zero if value == 0 else chroma / value


black = components(0.0, 0.0)
color = components(0.25, 0.5)
gray = components(0.0, 0.5)
print(black[1], color[1], gray[1])
print(isinstance(black[1], int), isinstance(color[1], float), isinstance(gray[1], float))
print(selected_saturation(0.0, 0.0), selected_saturation(0.25, 0.5))
print(isinstance(selected_saturation(0.0, 0.0), int), isinstance(selected_saturation(0.0, 0.5), float))
large = selected_saturation(0.0, 0.0, 9007199254740992 + 1)
print(large == 9007199254740992.0, 9007199254740992.0 < large)
print(1.25 + selected_saturation(0.0, 0.0), selected_saturation(0.25, 0.5) + 1.25)


def recursive_power(base: int, exponent: int) -> float:
    return base * recursive_power(base, exponent - 1) if exponent else 1


def display_power(base: int, exponent: int) -> None:
    result = recursive_power(base, abs(exponent))
    if exponent < 0:
        result = 1 / result
    print(result)


display_power(23, 12)
display_power(2, -3)
