def receive():
    sent = yield 1
    yield sent


def delegate():
    result = yield from receive()
    return result


def expression():
    return (yield 2) + 1
