import argparse
from typing import Any


class Label:
    text: str = "known"

    def __eq__(self, other) -> bool:
        return self.text == other.text


def typed_label(value: Label) -> str:
    return value.text.upper()


def name(value: Any) -> str:
    return value.label.upper()


def first(value: Any) -> str:
    return value.words[0]


def words(value: Any) -> None:
    for word in value.words:
        print(word.upper())


def enabled(value: Any) -> None:
    if value.enabled:
        print("enabled")
    else:
        print("disabled")


def argument() -> str:
    print("argument")
    return "x"


def missing_method(value: Any) -> None:
    try:
        value.missing(argument())
    except AttributeError:
        print("missing")


def non_callable(value: Any) -> None:
    try:
        value.label()
    except TypeError:
        print("not callable")


def call_value(value: Any) -> None:
    try:
        value(argument())
    except TypeError:
        print("not callable value")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--label", default="ada")
    parser.add_argument("--words", nargs="*", default=["cat", "dog"])
    parser.add_argument("--enabled", action="store_true")
    args = parser.parse_args([])
    print(name(args))
    print(first(args))
    words(args)
    enabled(args)
    missing_method(args)
    non_callable(args)
    call_value("text")
    print(typed_label(Label()))
    print(Label() == Label())
