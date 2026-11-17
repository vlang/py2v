def dynamic(value, types):
    return isinstance(value, types + (int, str))


def nested(value):
    return isinstance(value, (int, (str, float)))
