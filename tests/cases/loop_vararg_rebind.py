def vararg_rebind(*values: int) -> None:
    for values in values:
        pass
    print(values)


def vararg_branch_len(flag: bool, *values: int) -> None:
    if flag:
        n = len(values)
        for values in values:
            pass
        print(n)
    print(values)


def vararg_iter_len(*args: int) -> None:
    for i in range(len(args)):
        for args in [1, 2]:
            pass
    print(args)


vararg_rebind(2, 3)
vararg_branch_len(True, 2, 3)
vararg_branch_len(False, 2, 3)
vararg_iter_len(10, 20)
