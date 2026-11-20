def pair(value: int) -> tuple[int, str]:
    return value, "ready"


number, message = pair(7)
print(number, message)
