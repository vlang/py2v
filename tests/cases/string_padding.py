def main():
    # zfill
    print("42".zfill(5))
    print("hello".zfill(3))

    # ljust / rjust
    print("hi".ljust(6))
    print("hi".rjust(6))
    print("hi".ljust(6, "*"))
    print("hi".rjust(6, "-"))

    # center
    print("hi".center(6))
    print("hi".center(7, "-"))


if __name__ == "__main__":
    main()

