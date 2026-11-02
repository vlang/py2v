def try_finally_only() -> int:
    """`finally` maps onto V's defer, so its code survives."""
    result = 0
    try:
        result = 1
    finally:
        result += 10
    return result


def handler_is_reported() -> int:
    """A handler has no V equivalent, so it becomes a TODO rather than code
    that references an exception variable nothing ever bound."""
    value = 0
    try:
        value = risky()
    except ValueError as e:
        value = -1
    except (KeyError, TypeError):
        value = -2
    return value


def bare_handler() -> int:
    value = 0
    try:
        value = risky()
    except:
        value = -3
    return value


def else_is_dropped() -> int:
    value = 0
    try:
        value = 1
    except OSError:
        value = 2
    else:
        value = 3
    return value


def risky() -> int:
    return 1

class PortageException(Exception):
    def __init__(self, value):
        self.value = value


class PortageKeyError(KeyError, PortageException):
    """Mixes a builtin exception into a project hierarchy. V has no KeyError, so
    that base is dropped and reported; the project base becomes an embedded
    initialiser call."""

    def __init__(self, value):
        KeyError.__init__(self, value)
        PortageException.__init__(self, value)
