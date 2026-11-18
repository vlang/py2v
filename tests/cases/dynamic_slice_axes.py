def column(matrix, index: int):
    return matrix[:, index]


def window(matrix, start: int, stop: int, step: int):
    return matrix[start:stop:step, :, 3]


def set_column(matrix, index: int, value: int) -> None:
    matrix[:, index] = value


def set_window(matrix, start: int, stop: int, step: int, value: int) -> None:
    matrix[start:stop:step, :, 3] = value


def update_column(matrix, index: int, value: int) -> None:
    matrix[:, index] += value


def annotate_column(matrix, index: int, value: int) -> None:
    matrix[:, index]: int = value


def set_both(first, second, index: int, value: int) -> None:
    first[:, index] = second[1:, index] = value
