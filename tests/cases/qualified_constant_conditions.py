import token


def advance(kind: int, active: bool) -> int:
    while active and kind == token.STRING:
        kind += 1
    if kind == token.NUMBER:
        return kind + 1
    return kind


def follows() -> int:
    return 1
