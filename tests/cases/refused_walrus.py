def refused_walrus() -> None:
    values = [1]
    alias = values
    for value in values:
        if len(alias) < 3 and (ready := True):
            alias.append(value + 1)
    print(values)


def unrelated() -> None:
    print(7)


unrelated()
