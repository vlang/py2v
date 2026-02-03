def main():
    s = "hello world hello"

    # Find
    print(s.find("world"))
    print(s.find("xyz"))

    # Count
    print(s.count("l"))
    print(s.count("hello"))

    # Startswith and endswith
    print(s.startswith("hello"))
    print(s.startswith("world"))
    print(s.endswith("hello"))
    print(s.endswith("world"))


if __name__ == "__main__":
    main()
