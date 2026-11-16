def f(x: int) -> int:
    if x < 0:
        raise ValueError("negative")
    return x

def f_py(x: int) -> int:
    return x * 2

print(f(2), f_py(2))
