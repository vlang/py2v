def pred(x: int) -> bool:
    print(f'p{x}')
    return True
def value(x: int) -> int:
    print(f'v{x}')
    return x
values = [value(x) for x in [1, 2] if pred(x)]
print(values)
print([value(x) for x in range(1, 3) if pred(x)])
