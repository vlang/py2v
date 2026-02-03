def main():
    d = {"a": 1, "b": 2, "c": 3}

    # Keys
    keys = list(d.keys())
    print(keys)

    # Values
    values = list(d.values())
    print(values)

    # Get with default
    val = d.get("a", 0)
    print(val)
    val = d.get("z", 99)
    print(val)

    # Pop
    popped = d.pop("b")
    print(popped)
    print(d)

    # Update
    d.update({"x": 10, "y": 20})
    print(d)


if __name__ == "__main__":
    main()
