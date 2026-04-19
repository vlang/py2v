def add(*args: int) -> int:
    total = 0
    for n in args:
        total += n
    return total

nums = [1, 2, 3]
result = add(*nums)
print(result)

