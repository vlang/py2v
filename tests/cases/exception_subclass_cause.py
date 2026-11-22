class InvalidEntry(LookupError):
    pass


class MissingEntry(InvalidEntry):
    pass


def translate() -> None:
    try:
        raise ValueError("source")
    except ValueError as cause:
        raise MissingEntry("entry", 2) from cause


try:
    translate()
except InvalidEntry as problem:
    print(str(problem))
    print(problem.args)
    print(str(problem.__cause__))
