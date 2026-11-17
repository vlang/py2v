import unavailable as external


def compute(value: int) -> int:
    print(value)
    return value


def construct():
    return external.Widget(compute(1), compute(2), mode=compute(3))


def method(receiver):
    return receiver.Upper(compute(4), compute(5))
