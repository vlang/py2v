def param_collision_escape(N: int) -> int:
    for n in range(N):
        pass
    return n


def nested_escape() -> int:
    for x in [1, 2]:
        for x in [10, 20]:
            pass
    return x


def breakless_for_else_return() -> int:
    x = 0
    for x in [1, 2, 3]:
        pass
    else:
        return x


def breakless_for_else_scoped() -> int:
    for _ in range(2):
        pass
    else:
        msg: str
        if True:
            msg = "ok"
        print(msg)
    total = 0
    for msg in [10, 20]:
        msg = msg + 1
        total += msg
    return total


def vararg_early_return(flag: bool, *args: int) -> int:
    if flag:
        for args in [1, 2]:
            pass
        return 0
    return len(args)


def sequential_retype() -> str:
    for x in [1, 2]:
        pass
    for x in ["a", "b"]:
        pass
    return x


def unbound_shadow_comp(xs: list[int], flag: bool) -> list[int]:
    for x in xs:
        pass
    if xs:
        return [x]
    return [x + 1 for x in [10, 20]] if flag else []


print(param_collision_escape(3))
print(nested_escape())
print(breakless_for_else_return())
print(breakless_for_else_scoped())
print(vararg_early_return(False, 10, 20), vararg_early_return(True, 10, 20))
print(sequential_retype())
print(unbound_shadow_comp([], True))
print(unbound_shadow_comp([7], True))
