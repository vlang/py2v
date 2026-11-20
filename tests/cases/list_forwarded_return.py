def edit[T](values: list[T]) -> list[T]:
    copy_second(values)
    return values


def copy_second[T](values: list[T]) -> None:
    values[0] = values[1]


items = [1, 2]
print(edit(items))
print(items)
