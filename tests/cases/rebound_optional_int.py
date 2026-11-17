def number(value: int | None = None) -> None:
    if value is None:
        value = 7
    if value is not None:
        print(value)


number()
number(1.0)
