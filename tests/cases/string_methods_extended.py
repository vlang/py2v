def main():
    s = "hello world"

    # capitalize and title
    print(s.capitalize())
    print(s.title())

    # splitlines
    lines = "one\ntwo\nthree".splitlines()
    print(lines)

    # expandtabs
    tabbed = "a\tb\tc"
    print(tabbed.expandtabs(4))

    # encode → bytes
    b = "hello".encode("utf-8")
    print(b)

    # index (raises on not found, unlike find)
    idx = "hello world".index("world")
    print(idx)

    # count
    print("banana".count("a"))

    # isdigit / isalpha / isalnum
    print("123".isdigit())
    print("abc".isalpha())
    print("abc123".isalnum())


if __name__ == "__main__":
    main()

