from typing import Any


def caught_type(value: Any) -> None:
    try:
        value.join([1])
    except TypeError as error:
        print("caught type", str(error))


def caught_attr(value: Any) -> None:
    try:
        value.append(2)
    except AttributeError as error:
        print("caught attribute", str(error))


def relay(value: Any) -> None:
    value.append(2)


def propagate(value: Any) -> None:
    relay(value)


def receiver() -> Any:
    print("receiver")
    return []


def argument() -> int:
    print("argument")
    return 7


def success(value: Any) -> None:
    value.append(3)
    print(value)


if __name__ == "__main__":
    caught_type("")
    caught_attr(1)
    try:
        propagate(1)
    except AttributeError:
        print("propagated")
    value = receiver()
    value.append(argument())
    success([])
