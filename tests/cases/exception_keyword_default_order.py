default_offset = 7


def combine(first: int, second: int, offset: int = default_offset) -> int:
    if first < 0:
        raise ValueError("negative first argument")
    return first * 100 + second * 10 + offset


print(combine(first=1, second=2))
try:
    print(combine(first=-1, second=2))
except ValueError as exc:
    print(exc)
