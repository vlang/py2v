class EntryError(LookupError):
    pass


class MissingEntry(EntryError):
    pass


def lookup() -> None:
    raise MissingEntry("missing entry")


def read() -> None:
    try:
        try:
            lookup()
        except ValueError:
            print("unexpected")
    except LookupError as problem:
        print(problem)
        print(problem.args)


read()
