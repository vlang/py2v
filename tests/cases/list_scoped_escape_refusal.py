values = [1]
alias = values
alias.append(2)
refused_lambda = lambda: values < alias


def refused_default(value=((header_values := [1]), (header_alias := header_values),
                          header_alias.append(2), header_values < header_alias)[-1]) -> bool:
    return value


def refused_reader() -> list[int]:
    return values


def refused_closure() -> None:
    captured = [1]
    other = captured

    def read() -> list[int]:
        for value in captured:
            if len(other) < 3:
                other.append(value + 1)
        return captured

    print(read())


def unrelated() -> None:
    print(42)


if __name__ == '__main__':
    unrelated()
