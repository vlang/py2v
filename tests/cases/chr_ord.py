def main():
    # Ord - character to ASCII
    print(ord("A"))
    print(ord("Z"))
    print(ord("a"))
    print(ord("0"))

    # Chr - ASCII to character
    print(chr(65))
    print(chr(90))
    print(chr(97))
    print(chr(48))

    # Round trip
    c = "X"
    print(chr(ord(c)))


if __name__ == "__main__":
    main()
