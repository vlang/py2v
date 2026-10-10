#!/usr/bin/env python3
# A bare annotation with no value must still produce a legal V declaration.
# `x := <scalar>{}` is not valid V (`a := bool{}` does not parse), so scalars
# need an explicit zero literal while containers keep the `{}` form.


def flags() -> bool:
    enabled: bool
    count: int
    ratio: float
    label: str
    items: List[int]
    table: Dict[str, int]
    return enabled or count > 0 or ratio > 0.0 or label != "" or len(items) > 0 \
        or len(table) > 0