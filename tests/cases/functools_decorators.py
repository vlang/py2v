from functools import wraps, lru_cache, cache


@lru_cache(maxsize=128)
def fib(n: int) -> int:
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)


@cache
def factorial(n: int) -> int:
    if n == 0:
        return 1
    return n * factorial(n - 1)


def my_decorator(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        return func(*args, **kwargs)

    return wrapper


print(fib(10))
print(factorial(5))

