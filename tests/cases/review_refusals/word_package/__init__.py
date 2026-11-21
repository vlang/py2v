from value import HIGH, Box, word


def show_constant() -> None:
    print(oct(HIGH))


def show_call() -> None:
    print(oct(word()))


def show_field() -> None:
    box = Box()
    print(oct(box.value))


def show_method() -> None:
    box = Box()
    print(oct(box.get()))


if __name__ == "__main__":
    show_constant()
    show_call()
    show_field()
    show_method()
