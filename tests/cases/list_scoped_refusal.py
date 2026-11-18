def refused() -> None:
    values = [1]
    alias = values
    for value in values:
        if len(alias) < 3:
            alias.append(value + 1)
    print(values)


def refused_groups() -> list[int]:
    first = [1]
    first_alias = first
    for value in first:
        if len(first_alias) < 3:
            first_alias.append(value + 1)
    second = [4]
    second_alias = second
    second_alias.append(5)
    second = 'text'
    return second_alias


def refused_lambda_callback() -> None:
    print(list(filter(lambda _: ((values := [1]), (alias := values),
                                alias.append(2), values < alias)[-1] == True, [0])))


def unrelated() -> None:
    values = [4]
    alias = values
    alias.append(5)
    print(values)


class Methods:
    values: list[int]

    def refused(self) -> None:
        self.values = [1]
        alias = self.values
        for value in self.values:
            if len(alias) < 3:
                alias.append(value + 1)

    def unrelated(self) -> int:
        return 7


def refused_return() -> list[int]:
    values = [1]
    alias = values
    for value in values:
        if len(alias) < 3:
            alias.append(value + 1)
    return values


def refused_caller() -> None:
    print(refused_return())


if __name__ == '__main__':
    unrelated()
    print(Methods().unrelated())


def refused_default() -> None:
    def child(value=((values := [1]), (alias := values),
                     alias.append(2), values < alias)[-1]) -> bool:
        return value

    print(child())


def refused_received() -> None:
    received = 'one two'.split()
    received_alias = received
    received_alias.append('three')
    print(received)
