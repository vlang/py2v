def shell_guard(value: str) -> bool:
    return value.startswith('${')


def joined(value: str) -> str:
    return 'a${b}c' + value


def braced(value: str) -> str:
    return '${not an expression}'


def plain_dollar(value: str) -> str:
    return 'costs $5 and $ alone'


print(shell_guard('${x}'))
print(joined('z'))
print(braced('z'))
print(plain_dollar('z'))
