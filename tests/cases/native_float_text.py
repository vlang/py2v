def echo(x: float) -> float:
    print(x, str(x), f"{x!r}", sep="|")
    return x


one = 1.0
minus_zero = -0.0
print(echo(one))
print(echo(minus_zero))
values = [1e-4, 1e-5, 1e15, 1e16, 5e-324, 1.2345678901234567]
print(values[0], values[1], values[2], values[3], values[4], values[5])
print(echo(float("inf")), echo(float("-inf")), echo(float("nan")))
