def f(a: int, b: int, c: int) -> int:
    if a < 0:
        raise ValueError("bad")
    return a * 100 + b * 10 + c

def k() -> int:
    print("k")
    return 3

def g() -> int:
    print("g")
    return 1

def h() -> int:
    print("h")
    return 2

print(f(c=k(), a=g(), b=h()))
