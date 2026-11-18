def display(value: str, amount: float, precision: int) -> str:
    return "{!r}: {:,.{precision}f}".format(value, amount, precision=precision)


def named(value: str) -> str:
    return "{{label}} {name!r}".format(name=value)


def alternate_form(value: int) -> str:
    return "<value={:#x}>".format(value)
