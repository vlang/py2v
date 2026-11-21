def find(path: str | None) -> str | None:
    return path


def describe(path: str) -> str:
    return "[" + path + "]"


def report(path: str | None, fallback: str | None) -> str | None:
    if not path:
        path = find(fallback)
        if path is None:
            return None
    return describe(path)


if __name__ == "__main__":
    result = report(None, "found")
    if result is not None:
        print(result)
    print(report(None, None) is None)
