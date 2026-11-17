def column(matrix, index: int):
    return matrix[:, index]


def window(matrix, start: int, stop: int, step: int):
    return matrix[start:stop:step, :, 3]
