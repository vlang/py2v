def from_try(flag: bool):
    try:
        if not flag:
            raise ValueError("x")
        result = 10
    except ValueError:
        result = 20
    return result


if __name__ == "__main__":
    print(from_try(True))
    print(from_try(False))

