def pick_branch() -> bool:
    return True


if pick_branch():
    def choose(left: int, right: int) -> int:
        return left - right
else:
    def choose(left: int, right: int) -> int:
        return left + right


def local_read() -> int:
    if True:
        def read() -> int:
            return 4
    return read()
