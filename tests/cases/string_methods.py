def main():
    s = "  hello world  "

    # Strip whitespace
    stripped = s.strip()
    print(stripped)

    # Split string
    words = "one,two,three".split(",")
    print(words)

    # Join strings
    joined = "-".join(["a", "b", "c"])
    print(joined)

    # Upper and lower
    print("hello".upper())
    print("WORLD".lower())

    # Replace
    replaced = "hello".replace("l", "x")
    print(replaced)


if __name__ == "__main__":
    main()
