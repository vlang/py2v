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
