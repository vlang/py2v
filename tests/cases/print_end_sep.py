def main() -> None:
    for i in range(3):
        print(i, end="")
    print()
    for i in range(3):
        print(i, end=" ")
    print(end="\n")
    print("a", "b", "c", sep="-")
    print("a", "b", sep="")
    print(1, 2, 3, sep=", ", end="!\n")
    print("no newline", end="")
    print()
    print(end=" ")
    print("after space")
    name = "x"
    n = 4
    print(name, n, sep="=")
    print(name, n, end=";\n")
    print("it's", "quoted", sep="'")
    print(2.5, True, sep="|", end="\n")
    print("plain", "default")
    print("tab", end="\t")
    print("done")


if __name__ == "__main__":
    main()
