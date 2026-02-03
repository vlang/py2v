def maybe_value(flag: bool):
    if flag:
        return 42
    return None


def main():
    # None comparisons
    x = None
    print(x is None)
    print(x is not None)

    # Function returning None
    result = maybe_value(True)
    print(result)

    result = maybe_value(False)
    print(result is None)


if __name__ == "__main__":
    main()
