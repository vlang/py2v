def text(value: str | None = None) -> None:
    if value is None:
        value = "fallback"
    if value is not None:
        print(value)


def flag(value: bool | None = None) -> None:
    if value is None:
        value = True
    if value is not None:
        if value:
            print("enabled")


def overwrite(value: str | None = None) -> None:
    value = "changed"
    if value is not None:
        print(value)


text()
text("given")
flag()
caller = "original"
overwrite(caller)
print(caller)
caller_none: str | None = None
overwrite(caller_none)
if caller_none is None:
    print("caller-none")
