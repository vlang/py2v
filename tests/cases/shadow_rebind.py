def collect(path):
    return path


def first_existing(path):
    # A `for` variable that rebinds a parameter must not redeclare it in V.
    for path in collect(path):
        print(path)
    return path


def rebind_local(items):
    total = 0
    for total in items:
        print(total)
    return total


def destructure(path, rows):
    # Three or more targets are destructured by indexing, so each one is a
    # rebind when the name is already bound.
    for name, path, value in rows:
        print(name, path, value)


first_existing(1)
rebind_local([1, 2])
destructure('p', [(1, 2, 3)])
