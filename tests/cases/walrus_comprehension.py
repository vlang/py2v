#!/usr/bin/env python3
"""Test walrus (:=) operator inside comprehension filter expressions."""


def squares_above(n: int) -> list:
    # Walrus captures computed value reused in body
    return [y for x in range(n) if (y := x * x) > 5]


def evens_doubled(nums: list) -> list:
    # Walrus captures doubled value and tests it
    return [d for x in nums if (d := x * 2) % 4 == 0]


def nested_walrus(matrix: list) -> list:
    # Nested comprehension with walrus in inner filter
    return [z for row in matrix for z in row if (w := z * 3) > 6]


if __name__ == "__main__":
    print(squares_above(8))
    print(evens_doubled([1, 2, 3, 4, 5, 6]))
    print(nested_walrus([[1, 2, 3], [4, 5, 6]]))

