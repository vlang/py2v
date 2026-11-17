from ..provider import greet, configured, side_effect, shift, flag_name, combine


def keyword_mark(value: int) -> int:
    print(value)
    return value


def run_keywords() -> None:
    print(greet(name="Grace"))
    print(configured(right=keyword_mark(9)))
    print(side_effect(value=keyword_mark(3)))
    print(shift(value=keyword_mark(8)))
    print(configured(left=keyword_mark(4)))
    print(combine(first=keyword_mark(1), second=keyword_mark(2)))
    print(combine(3, second=keyword_mark(4)))
    print(flag_name())
