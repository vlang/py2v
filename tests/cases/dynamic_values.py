def add(a, b):
    return a + b


def biggest(xs):
    best = xs[0]
    for x in xs:
        if x > best:
            best = x
    return best


def first_or(xs, fallback):
    if xs:
        return xs[0]
    return fallback


def same(a, b):
    if a == b:
        return "same"
    return "different"


def total(xs):
    t = xs[0]
    for x in xs[1:]:
        t = t + x
    return t


print(add(1, 2))
print(add("a", "b"))
print(add(1.5, 2))
print(biggest([3, 9, 4]))
print(first_or([7], 0))
print(first_or("", "none"))
print(same(1, 1.0))
print(same("a", 1))
print(total([1, 2, 3]))
