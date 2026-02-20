def main():
    # Character classification predicates
    print("12345".isdigit())
    print("hello".isalpha())
    print("hello123".isalnum())
    print("   ".isspace())

    # Case predicates
    print("hello".islower())
    print("HELLO".isupper())
    print("Hello World".istitle())

    # False cases
    print("hello123".isdigit())
    print("hello123".isalpha())
    print("hello".isupper())


if __name__ == "__main__":
    main()
