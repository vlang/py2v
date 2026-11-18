def direct(value, kind):
    return isinstance(value, kind)


def captured(B):
    def check(value):
        if isinstance(value, B):
            return 1
        return 0
    return check


class Holder:
    def __init__(self, kind):
        self.kind = kind

    def make_check(self):
        def check(value):
            if isinstance(value, self.kind):
                return 1
            else:
                return 0
        return check


def tuple_types(value, kind):
    return isinstance(value, (int, kind))


def shadowed(value: int, int):
    return isinstance(value, int)


class Local:
    pass


def static(value):
    return isinstance(value, Local)


def dynamic(value, types):
    return isinstance(value, types + (int, str))


def nested(value):
    return isinstance(value, (int, (str, float)))
