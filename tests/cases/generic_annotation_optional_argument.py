import contextvars

var: contextvars.ContextVar[str | None] = contextvars.ContextVar("v", default=None)


def bind(value: str) -> contextvars.Token[str | None]:
    return var.set(value)


bind("x")
print(var.get())
