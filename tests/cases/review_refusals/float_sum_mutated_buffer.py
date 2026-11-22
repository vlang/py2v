def sum_after_write(value: int) -> float:
    data = [0.5]
    data[0] = value
    return sum(data[i] * 1 for i in range(1))


print(sum_after_write(1))
