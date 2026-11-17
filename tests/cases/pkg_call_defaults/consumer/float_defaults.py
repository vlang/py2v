from ..provider import (
    zero_default,
    unit_default,
    negative_default,
    negative_zero_default,
    float_any_default,
    int_any_default,
)


def run_float_defaults() -> None:
    print(zero_default())
    print(unit_default())
    print(negative_default())
    print(negative_zero_default())
    float_any_default()
    int_any_default()
    print(zero_default(2.5))
